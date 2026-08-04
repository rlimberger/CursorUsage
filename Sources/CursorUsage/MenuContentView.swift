import AppKit
import SwiftUI

struct MenuContentView: View {
    @Bindable var model: UsageViewModel
    @State private var openAtLogin = LoginItemManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let snapshot = model.snapshot {
                usageSection(snapshot)
            } else if model.isLoading {
                ProgressView("Loading usage…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text(model.planTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func usageSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            UsageBarRow(
                title: "Cursor Models",
                subtitle: "Includes Cursor Grok 4.5 and Composer 2.5",
                percent: snapshot.cursorModelsPercent,
                tint: Color(red: 0.55, green: 0.75, blue: 0.95),
                footnote: "Additional usage beyond limits consumes Other Models quota or on-demand spend."
            )

            UsageBarRow(
                title: "Other Models",
                subtitle: nil,
                percent: snapshot.otherModelsPercent,
                tint: Color(white: 0.78),
                footnote: "Additional usage beyond limits consumes on-demand spend."
            )

            if let reset = model.resetDetailText {
                Text(reset)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Open at Login", isOn: $openAtLogin)
                .toggleStyle(.checkbox)
                .font(.caption)
                .onChange(of: openAtLogin) { _, enabled in
                    if enabled {
                        _ = LoginItemManager.enable()
                    } else {
                        _ = LoginItemManager.disable()
                    }
                    openAtLogin = LoginItemManager.isEnabled
                }

            HStack(spacing: 12) {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r")

                Button("Open Dashboard") {
                    if let url = URL(string: "https://cursor.com/dashboard/usage") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

}

private struct UsageBarRow: View {
    let title: String
    let subtitle: String?
    let percent: Double
    let tint: Color
    let footnote: String

    private var clamped: Double {
        min(max(percent, 0), 100)
    }

    private var displayPercent: Int {
        Int(percent.rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text("\(displayPercent)% used")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(4, geo.size.width * clamped / 100))
                }
            }
            .frame(height: 6)

            Text(footnote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
