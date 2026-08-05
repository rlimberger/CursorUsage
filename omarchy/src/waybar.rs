use serde::Serialize;

use crate::usage::UsageSnapshot;

#[derive(Debug, Serialize, PartialEq)]
pub struct WaybarOutput {
    pub text: String,
    pub tooltip: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub class: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub percentage: Option<f64>,
}

/// Compact bar text matching the macOS app: `◆  14%  85%  13d`
pub fn format_text(snapshot: &UsageSnapshot) -> String {
    let cursor = format!("{}%", snapshot.cursor_percent_rounded());
    let other = format!("{}%", snapshot.other_percent_rounded());
    match snapshot.reset_countdown_text() {
        Some(days) => format!("◆  {cursor}  {other}  {days}"),
        None => format!("◆  {cursor}  {other}"),
    }
}

pub fn format_tooltip(snapshot: &UsageSnapshot) -> String {
    let mut lines = vec![
        snapshot.plan_title(),
        format!(
            "Cursor Models: {}% used",
            snapshot.cursor_percent_rounded()
        ),
        format!(
            "Other Models: {}% used",
            snapshot.other_percent_rounded()
        ),
    ];
    if let Some(reset) = snapshot.reset_detail_text() {
        lines.push(reset);
    }
    if let Some(msg) = &snapshot.cursor_models_message {
        if !msg.is_empty() {
            lines.push(msg.clone());
        }
    }
    lines.join("\n")
}

pub fn format_tooltip_with_email(snapshot: &UsageSnapshot, email: Option<&str>) -> String {
    let mut body = format_tooltip(snapshot);
    if let Some(email) = email {
        if !email.is_empty() {
            body.push('\n');
            body.push_str(email);
        }
    }
    body
}

pub fn from_snapshot(snapshot: &UsageSnapshot) -> WaybarOutput {
    let max_pct = snapshot
        .cursor_models_percent
        .max(snapshot.other_models_percent);
    let class = if max_pct >= 90.0 {
        Some("critical".to_string())
    } else if max_pct >= 75.0 {
        Some("warning".to_string())
    } else {
        Some("ok".to_string())
    };

    WaybarOutput {
        text: format_text(snapshot),
        tooltip: format_tooltip(snapshot),
        class,
        percentage: Some(max_pct),
    }
}

pub fn error_output(message: &str) -> WaybarOutput {
    WaybarOutput {
        text: "◆  !".to_string(),
        tooltip: message.to_string(),
        class: Some("error".to_string()),
        percentage: None,
    }
}

pub fn hidden_output() -> WaybarOutput {
    WaybarOutput {
        text: String::new(),
        tooltip: String::new(),
        class: Some("hidden".to_string()),
        percentage: None,
    }
}

pub fn to_json(output: &WaybarOutput) -> String {
    serde_json::to_string(output).unwrap_or_else(|_| {
        r#"{"text":"◆  !","tooltip":"JSON encode failed","class":"error"}"#.to_string()
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn sample() -> UsageSnapshot {
        UsageSnapshot {
            membership_type: "ultra".into(),
            cursor_models_percent: 14.0,
            other_models_percent: 85.0,
            total_percent: 50.0,
            billing_cycle_end: None,
            cursor_models_message: None,
            other_models_message: None,
            fetched_at: Utc::now(),
        }
    }

    #[test]
    fn formats_compact_bar_text() {
        assert_eq!(format_text(&sample()), "◆  14%  85%");
    }

    #[test]
    fn warning_class_at_75() {
        let mut snap = sample();
        snap.other_models_percent = 75.0;
        assert_eq!(from_snapshot(&snap).class.as_deref(), Some("warning"));
    }
}
