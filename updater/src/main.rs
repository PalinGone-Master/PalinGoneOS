//! PalinGoneOS — Centre de mise à jour.
//!
//! Fonctionnement :
//!   1. Vérification : `git ls-remote --tags` sur le dépôt de /etc/nixos (aucune écriture,
//!      aucun droit root), comparaison semver avec /etc/palingoneos/version.
//!   2. Mise à jour : démarre l'unité systemd `palingoneos-update@X.Y.Z.service`
//!      (autorisée par polkit pour le groupe wheel, voir palingoneos-update.nix).
//!      C'est cette unité, et non l'interface, qui tourne en root.
//!   3. Les logs sont suivis en direct via `journalctl -f`, l'interface ne se fige jamais.

use iced::futures::channel::{mpsc, oneshot};
use iced::futures::{SinkExt, StreamExt};
use iced::widget::{button, column, container, image, row, scrollable, text, Space};
use iced::{
    executor, subscription, theme, Alignment, Application, Color, Command, Element, Font, Length,
    Settings, Size, Subscription, Theme,
};
use std::any::TypeId;
use std::fmt;
use std::io::{BufRead, BufReader};
use std::process::{Command as Proc, Stdio};
use std::time::Duration;

const VERSION_FILE: &str = "/etc/palingoneos/version";
const FLAKE_DIR: &str = "/etc/nixos";
const MAX_LOG_LINES: usize = 5000;

/// Couleur de marque PalinGoneOS (le violet du losange et du "OS" du logo).
const BRAND_PURPLE: Color = Color::from_rgb(0x7A as f32 / 255.0, 0.0, 0x7A as f32 / 255.0);

/// Logo "PalinGoneOS" (losange + texte), affiché en haut de la fenêtre à la place
/// du texte "Bienvenue sur PalinGoneOS". Pixels bruts (RGBA), préparés à l'avance
/// depuis le logo officiel : pas de décodage d'image nécessaire au démarrage.
const WORDMARK_BYTES: &[u8] = include_bytes!("../branding/wordmark-480x122.rgba");
const WORDMARK_WIDTH: u32 = 480;
const WORDMARK_HEIGHT: u32 = 122;

/// Icône de la fenêtre (barre de titre / barre des tâches), même origine que le logo.
const ICON_BYTES: &[u8] = include_bytes!("../branding/icon-128x128.rgba");
const ICON_SIZE: u32 = 128;

/// Thème sombre personnalisé : mêmes couleurs que le thème sombre par défaut d'iced,
/// mais avec la couleur d'accent (boutons...) remplacée par le violet PalinGoneOS.
fn brand_theme() -> Theme {
    let dark = theme::Palette::DARK;
    Theme::custom(
        "PalinGoneOS".to_string(),
        theme::Palette {
            primary: BRAND_PURPLE,
            ..dark
        },
    )
}

fn window_icon() -> Option<iced::window::Icon> {
    iced::window::icon::from_rgba(ICON_BYTES.to_vec(), ICON_SIZE, ICON_SIZE).ok()
}

fn main() -> iced::Result {
    if std::env::var("WGPU_BACKEND").is_err() {
        std::env::set_var("WGPU_BACKEND", "vulkan,gl");
    }

    UpdaterApp::run(Settings {
        window: iced::window::Settings {
            size: Size::new(650.0, 500.0),
            resizable: false,
            decorations: true,
            icon: window_icon(),
            ..Default::default()
        },
        ..Default::default()
    })
}

// ---------------------------------------------------------------------------
// Versions (semver X.Y.Z strict : « 0.9.0 » < « 0.30.10 », contrairement aux String)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
struct Version(u32, u32, u32);

impl Version {
    /// Accepte « 0.30.10 » et « v0.30.10 ». Refuse tout le reste (« 1.0 », « 1.0-beta »…),
    /// pour rester aligné avec la validation du script côté système.
    fn parse(s: &str) -> Option<Self> {
        let mut parts = s.trim().trim_start_matches('v').split('.');
        let major = parts.next()?.parse::<u32>().ok()?;
        let minor = parts.next()?.parse::<u32>().ok()?;
        let patch = parts.next()?.parse::<u32>().ok()?;
        if parts.next().is_some() {
            return None;
        }
        Some(Self(major, minor, patch))
    }
}

impl fmt::Display for Version {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}.{}.{}", self.0, self.1, self.2)
    }
}

fn current_version() -> Result<Version, String> {
    let raw = std::fs::read_to_string(VERSION_FILE)
        .map_err(|e| format!("Impossible de lire {VERSION_FILE} : {e}"))?;
    Version::parse(&raw).ok_or_else(|| format!("Version installée illisible : « {} »", raw.trim()))
}

// ---------------------------------------------------------------------------
// Vérification des mises à jour (bloquante -> exécutée hors du thread de l'interface)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
enum CheckOutcome {
    UpToDate { current: Version },
    Available { current: Version, latest: Version },
}

fn check_updates() -> Result<CheckOutcome, String> {
    let current = current_version()?;

    let out = Proc::new("git")
        .args([
            // /etc/nixos appartient à root : sans ça, git refuse d'y travailler (« dubious ownership »).
            "-c",
            &format!("safe.directory={FLAKE_DIR}"),
            // Abandonne au lieu de rester bloqué sur un réseau capricieux.
            "-c",
            "http.lowSpeedLimit=1000",
            "-c",
            "http.lowSpeedTime=15",
            "-C",
            FLAKE_DIR,
            "ls-remote",
            "--tags",
            "--refs",
            "origin",
            "v*",
        ])
        .env("GIT_TERMINAL_PROMPT", "0")
        .stdin(Stdio::null())
        .output()
        .map_err(|e| format!("Impossible de lancer git : {e}"))?;

    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(format!(
            "Impossible de joindre le serveur de mises à jour.\nVérifiez votre connexion Internet.\n\n{}",
            err.trim()
        ));
    }

    let stdout = String::from_utf8_lossy(&out.stdout);
    let latest = stdout
        .lines()
        .filter_map(|line| line.split('\t').nth(1))
        .filter_map(|r| r.strip_prefix("refs/tags/"))
        .filter_map(Version::parse)
        .max();

    Ok(match latest {
        Some(latest) if latest > current => CheckOutcome::Available { current, latest },
        _ => CheckOutcome::UpToDate { current },
    })
}

/// Vrai si le noyau / l'initrd du système actif diffèrent de ceux du dernier démarrage.
fn reboot_needed() -> bool {
    ["kernel", "initrd", "kernel-modules"].iter().any(|name| {
        let booted = std::fs::canonicalize(format!("/run/booted-system/{name}"));
        let current = std::fs::canonicalize(format!("/run/current-system/{name}"));
        matches!((booted, current), (Ok(a), Ok(b)) if a != b)
    })
}

/// Exécute une fonction bloquante sur un thread dédié et rend le résultat en async.
async fn blocking<T, F>(f: F) -> T
where
    T: Send + 'static,
    F: FnOnce() -> T + Send + 'static,
{
    let (tx, rx) = oneshot::channel();
    std::thread::spawn(move || {
        let _ = tx.send(f());
    });
    rx.await.expect("le thread de travail s'est arrêté brutalement")
}

// ---------------------------------------------------------------------------
// Mise à jour : lancement de l'unité systemd + suivi des logs
// ---------------------------------------------------------------------------

fn pipe_lines<R: std::io::Read + Send + 'static>(
    reader: R,
    tx: mpsc::UnboundedSender<Message>,
) -> std::thread::JoinHandle<()> {
    std::thread::spawn(move || {
        for line in BufReader::new(reader).lines().map_while(Result::ok) {
            let _ = tx.unbounded_send(Message::UpdateLine(line));
        }
    })
}

fn run_update(version: Version, tx: mpsc::UnboundedSender<Message>) {
    let unit = format!("palingoneos-update@{version}.service");
    let say = |s: &str| {
        let _ = tx.unbounded_send(Message::UpdateLine(s.to_string()));
    };

    say(&format!("Démarrage de la mise à jour vers la version {version}…"));

    // On suit le journal AVANT de lancer l'unité pour ne rien perdre (-n 0 : pas d'historique).
    let mut journal = Proc::new("journalctl")
        .args(["-u", &unit, "-n", "0", "-f", "-o", "cat", "--no-pager"])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok();
    let reader = journal
        .as_mut()
        .and_then(|j| j.stdout.take())
        .map(|out| pipe_lines(out, tx.clone()));

    // Pour une unité oneshot, « start » ne rend la main qu'à la fin (succès ou échec).
    let result = Proc::new("systemctl").args(["start", &unit]).output();

    // Laisse au journal le temps de délivrer les dernières lignes.
    std::thread::sleep(Duration::from_millis(800));
    if let Some(j) = journal.as_mut() {
        let _ = j.kill();
        let _ = j.wait();
    }
    if let Some(handle) = reader {
        let _ = handle.join();
    }

    let success = match result {
        Ok(out) => {
            let err = String::from_utf8_lossy(&out.stderr);
            for line in err.lines().filter(|l| !l.trim().is_empty()) {
                say(line);
            }
            out.status.success()
        }
        Err(e) => {
            say(&format!("Impossible de lancer systemctl : {e}"));
            false
        }
    };

    let _ = tx.unbounded_send(Message::UpdateDone(success));
}

fn update_subscription(version: Version) -> Subscription<Message> {
    struct UpdateJob;

    subscription::channel(
        (TypeId::of::<UpdateJob>(), version),
        100,
        move |mut output| async move {
            let (tx, mut rx) = mpsc::unbounded::<Message>();
            std::thread::spawn(move || run_update(version, tx));

            while let Some(msg) = rx.next().await {
                let done = matches!(msg, Message::UpdateDone(_));
                let _ = output.send(msg).await;
                if done {
                    break;
                }
            }

            // Une subscription ne se termine jamais : elle est retirée quand l'état change.
            loop {
                iced::futures::future::pending::<()>().await;
            }
        },
    )
}

// ---------------------------------------------------------------------------
// Application
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
enum Message {
    Check,
    Checked(Result<CheckOutcome, String>),
    StartUpdate(Version),
    UpdateLine(String),
    UpdateDone(bool),
    Reboot,
}

enum State {
    Checking,
    UpToDate { current: Version },
    CheckFailed { error: String },
    Available { current: Version, latest: Version },
    Updating { version: Version, logs: Vec<String> },
    Finished { success: bool, reboot_needed: bool, logs: Vec<String> },
}

struct UpdaterApp {
    state: State,
}

fn logs_id() -> scrollable::Id {
    scrollable::Id::new("logs")
}

impl UpdaterApp {
    fn start_check() -> Command<Message> {
        Command::perform(blocking(check_updates), Message::Checked)
    }
}

impl Application for UpdaterApp {
    type Executor = executor::Default;
    type Message = Message;
    type Theme = Theme;
    type Flags = ();

    fn new(_flags: ()) -> (Self, Command<Message>) {
        (
            Self { state: State::Checking },
            Self::start_check(),
        )
    }

    fn title(&self) -> String {
        String::from("PalinGoneOS — Centre de Mise à Jour")
    }

    fn update(&mut self, message: Message) -> Command<Message> {
        match message {
            Message::Check => {
                self.state = State::Checking;
                Self::start_check()
            }

            Message::Checked(result) => {
                // On ignore un résultat tardif si l'utilisateur a déjà lancé autre chose.
                if !matches!(self.state, State::Checking) {
                    return Command::none();
                }
                self.state = match result {
                    Ok(CheckOutcome::UpToDate { current }) => State::UpToDate { current },
                    Ok(CheckOutcome::Available { current, latest }) => {
                        State::Available { current, latest }
                    }
                    Err(error) => State::CheckFailed { error },
                };
                Command::none()
            }

            Message::StartUpdate(version) => {
                self.state = State::Updating { version, logs: Vec::new() };
                Command::none() // la subscription démarre toute seule (voir `subscription`)
            }

            Message::UpdateLine(line) => {
                if let State::Updating { logs, .. } = &mut self.state {
                    logs.push(line);
                    if logs.len() > MAX_LOG_LINES {
                        logs.drain(..logs.len() - MAX_LOG_LINES);
                    }
                    return scrollable::snap_to(logs_id(), scrollable::RelativeOffset::END);
                }
                Command::none()
            }

            Message::UpdateDone(success) => {
                let logs = match &mut self.state {
                    State::Updating { logs, .. } => std::mem::take(logs),
                    _ => return Command::none(),
                };
                self.state = State::Finished {
                    success,
                    reboot_needed: success && reboot_needed(),
                    logs,
                };
                scrollable::snap_to(logs_id(), scrollable::RelativeOffset::END)
            }

            Message::Reboot => {
                let _ = Proc::new("systemctl").arg("reboot").spawn();
                Command::none()
            }
        }
    }

    fn subscription(&self) -> Subscription<Message> {
        match &self.state {
            State::Updating { version, .. } => update_subscription(*version),
            _ => Subscription::none(),
        }
    }

    fn view(&self) -> Element<Message> {
        let wordmark = image(image::Handle::from_pixels(
            WORDMARK_WIDTH,
            WORDMARK_HEIGHT,
            WORDMARK_BYTES,
        ))
        .width(Length::Fixed(WORDMARK_WIDTH as f32 * 0.8))
        .height(Length::Fixed(WORDMARK_HEIGHT as f32 * 0.8));

        let header = column![
            wordmark,
            text("Centre de maintenance et de mise à jour du système").size(14),
        ]
        .spacing(8)
        .align_items(Alignment::Center);

        let log_view = |logs: &[String]| {
            scrollable(text(logs.join("\n")).size(11).font(Font::MONOSPACE))
                .id(logs_id())
                .width(Length::Fill)
                .height(Length::Fill)
        };

        let content: Element<Message> = match &self.state {
            State::Checking => column![
                Space::with_height(Length::Fixed(20.0)),
                text("Recherche de mises à jour sur les serveurs PalinGoneOS…").size(14),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::UpToDate { current } => column![
                Space::with_height(Length::Fixed(20.0)),
                text("Votre système est entièrement à jour.").size(16),
                text(format!("Version installée : {current}")).size(13),
                Space::with_height(Length::Fixed(20.0)),
                button(text("Vérifier à nouveau").size(14))
                    .padding(10)
                    .on_press(Message::Check),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::CheckFailed { error } => column![
                Space::with_height(Length::Fixed(15.0)),
                text("La vérification des mises à jour a échoué.").size(16),
                scrollable(text(error).size(12)).height(Length::Fixed(110.0)),
                Space::with_height(Length::Fixed(10.0)),
                button(text("Réessayer").size(14))
                    .padding(10)
                    .on_press(Message::Check),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Available { current, latest } => column![
                Space::with_height(Length::Fixed(20.0)),
                text("Une nouvelle mise à jour système est disponible !").size(16),
                text(format!("de la version {current} vers la version {latest}")).size(14),
                Space::with_height(Length::Fixed(10.0)),
                text(
                    "L'opération peut durer plusieurs minutes.\n\
                     Gardez l'ordinateur branché et connecté à Internet."
                )
                .size(12),
                Space::with_height(Length::Fixed(15.0)),
                button(text("Lancer la mise à jour").size(16))
                    .padding(12)
                    .on_press(Message::StartUpdate(*latest)),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Updating { version, logs } => column![
                Space::with_height(Length::Fixed(5.0)),
                text(format!("Mise à jour vers {version} en cours, veuillez patienter…")).size(13),
                log_view(logs),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Finished { success, reboot_needed, logs } => {
                let title = if *success {
                    "Système mis à jour avec succès !"
                } else {
                    "Erreur lors de la mise à jour — votre système n'a pas été modifié"
                };

                let mut actions = row![].spacing(10);
                if *reboot_needed {
                    actions = actions.push(
                        button(text("Redémarrer maintenant").size(14))
                            .padding(10)
                            .on_press(Message::Reboot),
                    );
                }
                actions = actions.push(
                    button(text("Vérifier à nouveau").size(14))
                        .padding(10)
                        .on_press(Message::Check),
                );

                let mut col = column![text(title).size(18)]
                    .spacing(10)
                    .align_items(Alignment::Center);
                if *reboot_needed {
                    col = col.push(
                        text("Un redémarrage est nécessaire pour terminer la mise à jour.").size(13),
                    );
                }
                col.push(log_view(logs)).push(actions).into()
            }
        };

        container(
            column![header, Space::with_height(Length::Fixed(15.0)), content]
                .spacing(10)
                .align_items(Alignment::Center),
        )
        .width(Length::Fill)
        .height(Length::Fill)
        .padding(20)
        .center_x()
        .into()
    }

    fn theme(&self) -> Theme {
        brand_theme()
    }
}

#[cfg(test)]
mod tests {
    use super::Version;

    #[test]
    fn compare_numerically_not_lexically() {
        assert!(Version::parse("0.30.10") > Version::parse("0.9.0"));
        assert!(Version::parse("v1.0.0") > Version::parse("0.99.99"));
    }

    #[test]
    fn rejects_garbage() {
        assert_eq!(Version::parse("1.0"), None);
        assert_eq!(Version::parse("1.0.0-beta"), None);
        assert_eq!(Version::parse("1.0.0.1"), None);
        assert_eq!(Version::parse("abc"), None);
        assert_eq!(Version::parse("v0.30.10").map(|v| v.to_string()), Some("0.30.10".into()));
    }
}
