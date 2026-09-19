use iced::widget::{button, column, container, progress_bar, scrollable, text, vertical_space};
use iced::{Alignment, Element, Length, Sandbox, Settings, Theme};
use std::process::{Command, Stdio};

pub fn main() -> iced::Result {
    UpdaterApp::run(Settings {
        window: iced::window::Settings {
            size: (650, 500),
            resizable: false,
            decorations: true,
            ..Default::default()
        },
        ..Default::default()
    })
}

#[derive(Debug, Clone)]
enum Message {
    StartUpdate,
    UpdateProgress(f32, String),
}

enum State {
    Idle,
    Updating { progress: f32, logs: String },
    Finished { success: bool, logs: String },
}

struct UpdaterApp {
    state: State,
}

impl Sandbox for UpdaterApp {
    type Message = Message;

    fn new() -> Self {
        Self {
            state: State::Idle,
        }
    }

    fn title(&self) -> String {
        String::from("PalinGoneOS — Centre de Mise à Jour")
    }

    fn update(&mut self, message: Message) {
        match message {
            Message::StartUpdate => {
                self.state = State::Updating {
                    progress: 0.1,
                    logs: String::from("Démarrage de la mise à jour système...\n"),
                };
                
                // Exécution de nixos-rebuild
                // Note: Dans une version asynchrone complète (Command::perform), 
                // les logs s'affichent en temps réel via un canal.
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
            Message::UpdateProgress(p, log) => {
                if let State::Updating { logs, .. } = &mut self.state {
                    logs.push_str(&log);
                    self.state = State::Updating {
                        progress: p,
                        logs: logs.clone(),
                    };
                }
            }
        }
    }

    fn view(&self) -> Element<Message> {
        let header = column![
            text("Bienvenue sur PalinGoneOS")
                .size(28)
                .style(text::Danger),
            text("Centre de maintenance et de mise à jour du système")
                .size(14),
        ]
        .spacing(5)
        .align_items(Alignment::Center);

        let content: Element<Message> = match &self.state {
            State::Idle => column![
                vertical_space(20),
                text("Votre système est prêt à être mis à jour vers la dernière version de la flotte.")
                    .size(14),
                vertical_space(20),
                button(text("Lancer la mise à jour").size(16))
                    .padding(12)
                    .on_press(Message::StartUpdate),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Updating { progress, logs } => column![
                vertical_space(10),
                progress_bar(0.0..=1.0, *progress),
                text("Mise à jour en cours, veuillez patienter...").size(13),
                vertical_space(10),
                scrollable(text(logs).size(11))
                    .height(Length::Fill),
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),

            State::Finished { success, logs } => column![
                vertical_space(10),
                text(if *success { "Système mis à jour !" } else { "Erreur de mise à jour" })
                    .size(18),
                vertical_space(10),
                scrollable(text(logs).size(11))
                    .height(Length::Fill),
                vertical_space(10),
                button(text("Fermer").size(14))
                    .padding(8)
                    .on_press(Message::StartUpdate), // Ou quitter la fenêtre
            ]
            .spacing(10)
            .align_items(Alignment::Center)
            .into(),
        };

        container(
            column![header, vertical_space(15), content]
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
