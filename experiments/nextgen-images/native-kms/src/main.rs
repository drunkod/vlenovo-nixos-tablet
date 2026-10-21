use std::fs::{self, OpenOptions};
use std::io::Write;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

slint::slint! {
    import { LineEdit } from "std-widgets.slint";

    export component TabletDashboard inherits Window {
        title: "Lenovo Native OS MVP";
        width: 1100px;
        height: 720px;
        background: rgb(11, 16, 32);

        in-out property <string> battery-text: "Reading battery...";
        in-out property <string> memory-text: "Reading memory...";
        in-out property <string> network-text: "Reading Wi-Fi...";
        in-out property <string> uptime-text: "Reading uptime...";
        in-out property <string> touch-text: "Reading touchscreen...";
        in-out property <string> output-text: "Select a command to see live Linux data.";
        in-out property <string> command-text: "status";
        in-out property <int> touch-count: 0;
        callback action(string);

        VerticalLayout {
            padding: 28px;
            spacing: 18px;

            HorizontalLayout {
                height: 100px;
                VerticalLayout {
                    spacing: 5px;
                    Text { text: "Lenovo OS"; font-size: 45px; font-weight: 700; color: #f3f6ff; }
                    Text { text: "NATIVE RUST + SLINT   /   NO SYSTEM CHANGES"; font-size: 17px; color: #87acc9; }
                }
                Rectangle {
                    width: 230px;
                    border-radius: 15px;
                    background: #17372d;
                    Text {
                        text: "● LIVE / LOCAL";
                        color: rgb(132, 234, 187);
                        font-size: 20px;
                        horizontal-alignment: center;
                        vertical-alignment: center;
                    }
                }
            }

            HorizontalLayout {
                height: 125px;
                spacing: 14px;

                Rectangle {
                    border-radius: 17px;
                    background: #1c3051;
                    VerticalLayout {
                        padding: 15px;
                        spacing: 8px;
                        Text { text: "BATTERY"; font-size: 17px; color: #91bcff; }
                        Text { text: root.battery-text; font-size: 23px; color: white; }
                    }
                }
                Rectangle {
                    border-radius: 17px;
                    background: #26314d;
                    VerticalLayout {
                        padding: 15px;
                        spacing: 8px;
                        Text { text: "MEMORY"; font-size: 17px; color: #9cb5ff; }
                        Text { text: root.memory-text; font-size: 23px; color: white; }
                    }
                }
                Rectangle {
                    border-radius: 17px;
                    background: #1b423e;
                    VerticalLayout {
                        padding: 15px;
                        spacing: 8px;
                        Text { text: "WI-FI"; font-size: 17px; color: rgb(133, 234, 198); }
                        Text { text: root.network-text; font-size: 23px; color: white; }
                    }
                }
            }

            Text { text: "Read-only commands"; font-size: 27px; color: #eef3ff; height: 44px; }

            HorizontalLayout {
                spacing: 14px;
                height: 150px;
                Rectangle {
                    background: #214575;
                    border-radius: 18px;
                    VerticalLayout {
                        padding: 18px;
                        spacing: 12px;
                        Text { text: "01 STATUS"; color: #96cbff; font-size: 20px; }
                        Text { text: "System overview"; color: white; font-size: 25px; }
                    }
                    TouchArea { clicked => { root.action("status"); } }
                }
                Rectangle {
                    background: #343555;
                    border-radius: 18px;
                    VerticalLayout {
                        padding: 18px;
                        spacing: 12px;
                        Text { text: "02 ASSIST"; color: #dacaff; font-size: 20px; }
                        Text { text: "Local help"; color: white; font-size: 25px; }
                    }
                    TouchArea { clicked => { root.action("help"); } }
                }
                Rectangle {
                    background: #17564b;
                    border-radius: 18px;
                    VerticalLayout {
                        padding: 18px;
                        spacing: 12px;
                        Text { text: "03 NETWORK"; color: #95f4d5; font-size: 20px; }
                        Text { text: "Link status"; color: white; font-size: 25px; }
                    }
                    TouchArea { clicked => { root.action("network"); } }
                }
            }

            HorizontalLayout {
                height: 58px;
                spacing: 12px;
                LineEdit {
                    text <=> root.command-text;
                    accepted => { root.action(root.command-text); }
                }
                Rectangle {
                    width: 154px;
                    background: #3976b8;
                    border-radius: 13px;
                    Text { text: "RUN"; color: white; font-size: 23px; horizontal-alignment: center; vertical-alignment: center; }
                    TouchArea { clicked => { root.action(root.command-text); } }
                }
            }

            Rectangle {
                height: 130px;
                border-radius: 16px;
                background: #17243b;
                VerticalLayout {
                    padding: 16px;
                    spacing: 8px;
                    Text { text: "RESULT  /  ACTIONS: " + root.touch-count; color: #81bafb; font-size: 18px; }
                    Text { text: root.output-text; color: #f5f7ff; wrap: word-wrap; font-size: 21px; }
                }
            }

            HorizontalLayout {
                spacing: 18px;
                Text { text: root.uptime-text; color: #8aa2bf; font-size: 18px; }
                Text { text: root.touch-text; color: rgb(146, 239, 194); font-size: 18px; }
            }
        }
    }
}

fn read_trimmed(path: &str) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}
fn available_mib() -> Option<u64> {
    let mem = fs::read_to_string("/proc/meminfo").ok()?;
    mem.lines().find(|l| l.starts_with("MemAvailable:"))?
        .split_whitespace().nth(1)?.parse::<u64>().ok().map(|v| v / 1024)
}
fn total_mib() -> Option<u64> {
    let mem = fs::read_to_string("/proc/meminfo").ok()?;
    mem.lines().find(|l| l.starts_with("MemTotal:"))?
        .split_whitespace().nth(1)?.parse::<u64>().ok().map(|v| v / 1024)
}
fn uptime_secs() -> Option<u64> {
    fs::read_to_string("/proc/uptime").ok()?
        .split_whitespace().next()?.parse::<f64>().ok().map(|s| s as u64)
}
fn battery() -> String {
    match (read_trimmed("/sys/class/power_supply/BATC/capacity"),
           read_trimmed("/sys/class/power_supply/BATC/status")) {
        (Some(percent), Some(status)) => format!("{percent}%  {status}"),
        _ => "Not available".into(),
    }
}
fn network() -> String {
    match read_trimmed("/sys/class/net/wlan0/operstate") {
        Some(s) if s == "up" => "Wi-Fi link up".into(),
        Some(s) => format!("Wi-Fi {s}"),
        None => "Wi-Fi unknown".into(),
    }
}
fn uptime_string() -> String {
    let s = uptime_secs().unwrap_or(0);
    format!("UPTIME {}h {}m", s / 3600, (s / 60) % 60)
}
fn touch_health() -> String {
    let detected = fs::read_link("/dev/input/by-path/first-touchscreen").is_ok();
    let d0 = read_trimmed("/sys/bus/acpi/devices/ELAN1001:00/power_state")
        .as_deref() == Some("D0");
    if detected && d0 { "ELAN TOUCH READY".into() } else { "ELAN TOUCH NOT READY".into() }
}
fn refresh(ui: &TabletDashboard) {
    ui.set_battery_text(battery().into());
    ui.set_memory_text(match (available_mib(), total_mib()) {
        (Some(a), Some(t)) => format!("{a} / {t} MiB avail.").into(),
        _ => "Unavailable".into(),
    });
    ui.set_network_text(network().into());
    ui.set_uptime_text(uptime_string().into());
    ui.set_touch_text(touch_health().into());
}
fn handle(cmd: &str) -> String {
    // Not a shell. Exact allowlist, entirely read-only.
    match cmd.trim().to_ascii_lowercase().as_str() {
        "status" => format!("{}; {}; {}; {}.",
            battery(), network(), available_mib().map(|v| format!("{v} MiB available")).unwrap_or_default(),
            uptime_string().to_ascii_lowercase()),
        "memory" => format!("Linux reports {} MiB available of {} MiB RAM.",
            available_mib().unwrap_or(0), total_mib().unwrap_or(0)),
        "battery" => format!("Tablet BATC: {}.", battery()),
        "network" | "wifi" => format!("{} (interface wlan0; read-only).", network()),
        "uptime" => uptime_string(),
        "help" | "assist" => "Local commands: status, battery, memory, network, uptime, help. AI integration is not installed.".into(),
        _ => "Unknown command. Allowed: status, battery, memory, network, uptime, help.".into(),
    }
}
fn log_action(cmd: &str) {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/alex".to_string());
    let path = format!("{home}/lenovo-mvp/native-events.tsv");
    if let Ok(mut f) = OpenOptions::new().append(true).create(true).open(path) {
        let ts = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
        let safe: String = cmd.chars().filter(|c| c.is_ascii_alphanumeric() || *c == '-' || *c == '_').take(32).collect();
        let _ = writeln!(f, "{ts}\t{safe}");
    }
}
fn main() -> Result<(), slint::PlatformError> {
    let ui = TabletDashboard::new()?;
    refresh(&ui);
    let weak = ui.as_weak();
    ui.on_action(move |cmd| {
        let result = handle(&cmd);
        log_action(&cmd);
        if let Some(ui) = weak.upgrade() {
            ui.set_touch_count(ui.get_touch_count() + 1);
            ui.set_output_text(result.into());
            refresh(&ui);
        }
    });
    let timer = slint::Timer::default();
    let weak = ui.as_weak();
    timer.start(slint::TimerMode::Repeated, Duration::from_secs(12), move || {
        if let Some(ui) = weak.upgrade() { refresh(&ui); }
    });
    ui.run()
}
