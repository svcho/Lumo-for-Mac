import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // ── Display ──
            VStack(alignment: .leading, spacing: 12) {
                Text("Display")
                    .font(.headline)
                    .fontWeight(.semibold)

                Toggle("Custom user agent (better compatibility)", isOn: $settings.customUserAgent)
            }

            Divider()

            // ── Privacy & Performance ──
            VStack(alignment: .leading, spacing: 12) {
                Text("Privacy & Performance")
                    .font(.headline)
                    .fontWeight(.semibold)

                Toggle("Block trackers", isOn: $settings.blockTrackers)
                Toggle("Enable spell checking", isOn: $settings.enableSpellChecking)
            }

            Divider()

            // ── Zoom ──
            VStack(alignment: .leading, spacing: 12) {
                Text("Zoom")
                    .font(.headline)
                    .fontWeight(.semibold)

                HStack {
                    Slider(value: $settings.zoomLevel, in: 0.5...3.0, step: 0.1)
                    Text(String(format: "%.0f%%", settings.zoomLevel * 100))
                        .monospacedDigit()
                        .frame(width: 50)
                }
                Button("Reset to 100%") {
                    settings.zoomLevel = 1.0
                }
            }

            Divider()

            // ── Session Info ──
            VStack(alignment: .leading, spacing: 8) {
                Text("Session")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Your Proton login session is persisted across app launches. Use File → Clear Session & Reload to sign out.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 480)
    }
}