use iced::widget::{button, column, container, scrollable, text, Space};
use iced::{Alignment, Element, Length, Sandbox, Settings, Size, Theme};
use std::process::{Command, Stdio};

pub fn main() -> iced::Result {
    // Forcer le backend de rendu OpenGL si Vulkan échoue
    std::env::set_var("WGPU_BACKEND", "gl");

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
    StartUpdate,
}

enum State {
    Idle,
    Updating { logs: String },
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
                    logs: String::from("Démarrage de la mise à jour système...\n"),
                };

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
            State::Idle => column![
                Space::with_height(Length::Fixed(20.0)),
                text("Votre système est prêt à être mis à jour vers la dernière version de la flotte.")
                    .size(14),
                Space::with_height(Length::Fixed(20.0)),
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
                text(if *success { "Système mis à jour !" } else { "Erreur de mise à jour" })
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
