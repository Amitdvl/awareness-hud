import AwarenessCore
import SwiftUI

struct AwarenessHUDView: View {
    @ObservedObject var monitor: ActivityMonitor

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            narrativeText
        }
        .font(.system(size: 23, weight: .medium, design: .rounded))
        .lineSpacing(5)
        .multilineTextAlignment(.leading)
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 34)
        .padding(.vertical, 24)
        .frame(width: 820, alignment: .leading)
        .background(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var narrativeText: Text {
        let snapshot = monitor.snapshot
        let duration = DurationFormatter.short(snapshot.capturedAt.timeIntervalSince(snapshot.activityStartedAt))

        if let websiteTitle = snapshot.websiteTitle,
           let websiteHost = snapshot.websiteHost,
           let browserName = snapshot.browserName {
            return Text("You’ve been on ")
                + accent(websiteHost)
                + Text(" — \(websiteTitle) — in ")
                + accent(browserName)
                + Text(" for ")
                + accent(duration)
                + Text(". You’ve switched context \(snapshot.contextSwitchCount) times this session.")
        }

        let window = snapshot.windowTitle.map { " — \($0)" } ?? ""
        return Text("You’ve been in ")
            + accent(snapshot.appName)
            + Text("\(window) for ")
            + accent(duration)
            + Text(". You’ve switched context \(snapshot.contextSwitchCount) times this session.")
    }

    private func accent(_ value: String) -> Text {
        Text(value).foregroundStyle(Color(red: 0.62, green: 0.60, blue: 1.0))
    }
}
