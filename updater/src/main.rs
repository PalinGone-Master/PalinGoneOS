use iced::widget::{button, column, container, scrollable, text, Space};
use iced::{Alignment, Element, Length, Sandbox, Settings, Size, Theme};
use std::process::{Command, Stdio};

pub fn main() -> iced::Result {
    if std::env::var("WGPU_BACKEND").is_err() {
        std::env::set_var("WGPU_BACKEND", "vulkan,gl");
    }

    UpdaterApp::run(Settings {
        window: iced::window::Settings {
            size: Size::new(650.0, 500.0),
            resizable: false,
            decorations: true,
            ..Default::default()
        },
        ..Default::default()
    })
}

#[derive(Debug, Clone)]
enum Message {
    CheckForUpdates,
    StartUpdate,
}

enum State {
    Checking,
    UpToDate,
    UpdateAvailable { new_commits: String },
    Updating { logs: String },
    Finished { success: bool, logs: String },
}

struct UpdaterApp {
    state: State,
}

impl Sandbox for UpdaterApp {
    type Message = Message;

    fn new() -> Self {
        let mut app = Self {
            state: State::Checking,
        };
        app.check_updates();
        app
    }

    fn title(&self) -> String {
        String::from("PalinGoneOS — Centre de Mise à Jour")
    }

    fn update(&mut self, message: Message) {
        match message {
            Message::CheckForUpdates => {
                self.check_updates();
            }
            Message::StartUpdate => {
                self.state = State::Updating {
                    logs: String::from("Démarrage de la mise à jour système...\n"),
                };

                // Mise à jour du Flake et reconstruction système
                let output = Command::new("sudo")
                    .args(["nixos-rebuild", "switch", "--flake", "/etc/nixos#palingoneos"])
                    .stdout(Stdio::piped())
                    .stderr(Stdio::piped())
                    .output();

                match output {
                    Ok(out) => {
                        let stdout = String::from_utf8_lossy(&out.stdout);
                        let stderr = String::from_utf8_lossy(&out.stderr);
                        let full_log = format!("{}\n{}", stdout, stderr);

                        if out.status.success() {
                            self.state = State::Finished {
                                success: true,
                                logs: format!("Mise à jour terminée avec succès !\n\n{}", full_log),
                            };
                        } else {
                            self.state = State::Finished {
                                success: false,
                                logs: format!("Échec de la mise à jour :\n\n{}", full_log),
                            };
                        }
                    }
                    Err(e) => {
                        self.state = State::Finished {
                            success: false,
                            logs: format!("Erreur lors du lancement de la commande : {}", e),
                        };
                    }
                }
            }
        }
    }

    fn view(&self) -> Element<Message> {
        let header = column![
            text("Bienvenue sur PalinGoneOS")
                .size(28),
            text("Centre de maintenance et de mise à jour du système")
                .size(14),
        ]
        .spacing(5)
        .align_items(Alignment::Center);

        let content: Element<Message> = match &self.state {
            State::Checking => column![
                Space::with_height(Length::Fixed(20.0)),
                text("Recherche de mises à jour sur les serveurs PalinGoneOS...")
                    .size(14),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::UpToDate => column![
                Space::with_height(Length::Fixed(20.0)),
                text("Votre système est entièrement à jour.")
                    .size(16),
                Space::with_height(Length::Fixed(20.0)),
                button(text("Vérifier à nouveau").size(14))
                    .padding(10)
                    .on_press(Message::CheckForUpdates),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::UpdateAvailable { new_commits } => column![
                Space::with_height(Length::Fixed(15.0)),
                text("Une nouvelle mise à jour système est disponible !")
                    .size(16),
                Space::with_height(Length::Fixed(10.0)),
                scrollable(text(new_commits).size(11))
                    .height(Length::Fixed(120.0)),
                Space::with_height(Length::Fixed(15.0)),
                button(text("Lancer la mise à jour").size(16))
                    .padding(12)
                    .on_press(Message::StartUpdate),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Updating { logs } => column![
                Space::with_height(Length::Fixed(10.0)),
                text("Mise à jour en cours, veuillez patienter...").size(13),
                Space::with_height(Length::Fixed(10.0)),
                scrollable(text(logs).size(11))
                    .height(Length::Fill),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Finished { success, logs } => column![
                Space::with_height(Length::Fixed(10.0)),
                text(if *success { "Système mis à jour avec succès !" } else { "Erreur lors de la mise à jour" })
                    .size(18),
                Space::with_height(Length::Fixed(10.0)),
                scrollable(text(logs).size(11))
                    .height(Length::Fill),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),
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
        Theme::Dark
    }
}

impl UpdaterApp {
    fn check_updates(&mut self) {
        // Fetch les commits distants depuis /etc/nixos
        let _ = Command::new("git")
            .args(["-C", "/etc/nixos", "fetch", "origin"])
            .output();

        // Comparer le HEAD local avec origin/main
        let status = Command::new("git")
            .args(["-C", "/etc/nixos", "log", "HEAD..origin/main", "--oneline"])
            .output();

        match status {
            Ok(out) => {
                let commits = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if commits.is_empty() {
                    self.state = State::UpToDate;
                } else {
                    self.state = State::UpdateAvailable {
                        new_commits: format!("Nouveautés disponibles :\n{}", commits),
                    };
                }
            }
            Err(_) => {
                // Si pas de réseau ou erreur git, on retombe sur l'état à jour par sécurité
                self.state = State::UpToDate;
            }
        }
    }
}
