use chrono::{DateTime, Local, TimeZone, Utc};
use serde::Deserialize;
use thiserror::Error;

use crate::auth::{AuthError, Credentials};

const ENDPOINT: &str =
    "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage";

#[derive(Debug, Clone, PartialEq)]
pub struct UsageSnapshot {
    pub membership_type: String,
    pub cursor_models_percent: f64,
    pub other_models_percent: f64,
    pub total_percent: f64,
    pub billing_cycle_end: Option<DateTime<Utc>>,
    pub cursor_models_message: Option<String>,
    pub other_models_message: Option<String>,
    pub fetched_at: DateTime<Utc>,
}

#[derive(Debug, Error)]
pub enum UsageError {
    #[error(transparent)]
    Auth(#[from] AuthError),
    #[error("Usage API returned HTTP {0}")]
    BadHttpStatus(u16),
    #[error("Could not parse usage response")]
    DecodeFailed,
    #[error("Cursor session expired. Sign in to Cursor again.")]
    NotAuthenticated,
    #[error(transparent)]
    Request(#[from] reqwest::Error),
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PeriodUsageResponse {
    plan_usage: Option<PlanUsage>,
    membership_type: Option<String>,
    billing_cycle_end: Option<String>,
    auto_model_selected_display_message: Option<String>,
    named_model_selected_display_message: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PlanUsage {
    auto_percent_used: Option<f64>,
    api_percent_used: Option<f64>,
    total_percent_used: Option<f64>,
}

pub fn fetch_usage_with(credentials: &Credentials) -> Result<UsageSnapshot, UsageError> {
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(20))
        .build()?;

    let response = client
        .post(ENDPOINT)
        .header("Authorization", format!("Bearer {}", credentials.access_token))
        .header("Content-Type", "application/json")
        .header("Connect-Protocol-Version", "1")
        .body("{}")
        .send()?;

    let status = response.status();
    if status.as_u16() == 401 || status.as_u16() == 403 {
        return Err(UsageError::NotAuthenticated);
    }
    if !status.is_success() {
        return Err(UsageError::BadHttpStatus(status.as_u16()));
    }

    let decoded: PeriodUsageResponse = response.json().map_err(|_| UsageError::DecodeFailed)?;
    snapshot_from_response(credentials, decoded)
}

fn snapshot_from_response(
    credentials: &Credentials,
    decoded: PeriodUsageResponse,
) -> Result<UsageSnapshot, UsageError> {
    let plan = decoded.plan_usage.ok_or(UsageError::DecodeFailed)?;

    let membership = credentials
        .membership_type
        .clone()
        .or(decoded.membership_type)
        .unwrap_or_else(|| "unknown".to_string());
    let membership = {
        let trimmed = membership.trim();
        if trimmed.is_empty() {
            "unknown".to_string()
        } else {
            trimmed.to_string()
        }
    };

    Ok(UsageSnapshot {
        membership_type: membership,
        cursor_models_percent: plan.auto_percent_used.unwrap_or(0.0),
        other_models_percent: plan.api_percent_used.unwrap_or(0.0),
        total_percent: plan.total_percent_used.unwrap_or(0.0),
        billing_cycle_end: parse_billing_cycle_end(decoded.billing_cycle_end.as_deref()),
        cursor_models_message: decoded.auto_model_selected_display_message,
        other_models_message: decoded.named_model_selected_display_message,
        fetched_at: Utc::now(),
    })
}

fn parse_billing_cycle_end(raw: Option<&str>) -> Option<DateTime<Utc>> {
    let raw = raw?;
    if let Ok(ms) = raw.parse::<f64>() {
        let secs = (ms / 1000.0) as i64;
        return Utc.timestamp_opt(secs, 0).single();
    }
    DateTime::parse_from_rfc3339(raw)
        .ok()
        .map(|dt| dt.with_timezone(&Utc))
}

impl UsageSnapshot {
    pub fn cursor_percent_rounded(&self) -> i64 {
        self.cursor_models_percent.round() as i64
    }

    pub fn other_percent_rounded(&self) -> i64 {
        self.other_models_percent.round() as i64
    }

    pub fn days_until_reset(&self) -> Option<i64> {
        let end = self.billing_cycle_end?;
        let today = Local::now().date_naive();
        let end_day = end.with_timezone(&Local).date_naive();
        Some((end_day - today).num_days())
    }

    pub fn reset_countdown_text(&self) -> Option<String> {
        let days = self.days_until_reset()?;
        if days <= 0 {
            Some("0d".to_string())
        } else {
            Some(format!("{days}d"))
        }
    }

    pub fn plan_title(&self) -> String {
        let plan = capitalize_first(&self.membership_type);
        format!("Included in {plan}")
    }

    pub fn reset_detail_text(&self) -> Option<String> {
        let end = self.billing_cycle_end?;
        let date = end.with_timezone(&Local).format("%b %e").to_string().replace("  ", " ");
        match self.days_until_reset() {
            None => Some(format!("Resets {date}")),
            Some(d) if d <= 0 => Some(format!("Resets today ({date})")),
            Some(1) => Some(format!("Resets in 1 day ({date})")),
            Some(d) => Some(format!("Resets in {d} days ({date})")),
        }
    }
}

fn capitalize_first(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_period_usage_json() {
        let json = r#"{
            "planUsage": {
                "autoPercentUsed": 14.2,
                "apiPercentUsed": 85.4,
                "totalPercentUsed": 50.0
            },
            "membershipType": "ultra",
            "billingCycleEnd": "1771372800000",
            "autoModelSelectedDisplayMessage": "Cursor models",
            "namedModelSelectedDisplayMessage": "Other models"
        }"#;
        let decoded: PeriodUsageResponse = serde_json::from_str(json).unwrap();
        let creds = Credentials {
            access_token: "t".into(),
            membership_type: Some("pro".into()),
            email: None,
        };
        let snap = snapshot_from_response(&creds, decoded).unwrap();
        assert_eq!(snap.cursor_percent_rounded(), 14);
        assert_eq!(snap.other_percent_rounded(), 85);
        assert_eq!(snap.membership_type, "pro");
        assert!(snap.billing_cycle_end.is_some());
    }
}
