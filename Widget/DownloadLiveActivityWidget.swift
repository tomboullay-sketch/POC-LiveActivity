import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DownloadWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivityWidget()
    }
}

/// The download Live Activity: lock screen banner and Dynamic Island.
struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            HStack(spacing: 12) {
                AppLogo(size: 44)
                TitleBlock(context: context)
                Spacer(minLength: 0)
                StopButton(context: context, size: 48)
            }
            .padding(16)
            .foregroundStyle(.white)
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AppLogo(size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StopButton(context: context, size: 44)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TitleBlock(context: context)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                AppLogo(size: 22)
            } compactTrailing: {
                ProgressRing(progress: context.state.progress, lineWidth: 3)
                    .frame(width: 20, height: 20)
            } minimal: {
                ProgressRing(progress: context.state.progress, lineWidth: 3)
                    .frame(width: 20, height: 20)
            }
        }
    }
}

private struct TitleBlock: View {
    let context: ActivityViewContext<DownloadActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.title)
                .font(.headline)
                .lineLimit(1)
            Text(status)
                .font(.subheadline)
                .monospacedDigit()
                .opacity(0.8)
            if context.state.phase == .downloading {
                Text("Mis à jour il y a \(Text(context.state.updatedAt, style: .relative))")
                    .font(.caption)
                    .opacity(0.6)
            }
        }
    }

    private var status: String {
        switch context.state.phase {
        case .downloading: "\(context.attributes.kindLabel) · \(Int(context.state.progress * 100)) %"
        case .finished: "Téléchargement terminé"
        case .cancelled: "Téléchargement annulé"
        case .failed: "Échec du téléchargement"
        }
    }
}

/// The loading ring with a stop button inside, which cancels the download through `CancelDownloadIntent`.
private struct StopButton: View {
    let context: ActivityViewContext<DownloadActivityAttributes>
    let size: CGFloat

    var body: some View {
        switch context.state.phase {
        case .downloading:
            Button(intent: CancelDownloadIntent(downloadID: context.attributes.downloadID)) {
                ZStack {
                    ProgressRing(progress: context.state.progress, lineWidth: 4)
                    Image(systemName: "stop.fill")
                        .font(.system(size: size * 0.3, weight: .bold))
                }
                .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
        case .finished:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size * 0.8))
                .foregroundStyle(.green)
        case .cancelled, .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: size * 0.8))
                .foregroundStyle(.red)
        }
    }
}

private struct ProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(.cyan, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct AppLogo: View {
    let size: CGFloat

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
