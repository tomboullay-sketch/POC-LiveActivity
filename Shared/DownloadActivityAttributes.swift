import ActivityKit
import Foundation

/// Data shown by the download Live Activity.
///
/// Compiled in the app (which starts and updates the activity) and in the widget extension (which draws it).
struct DownloadActivityAttributes: ActivityAttributes {
    /// The part of the activity the app updates while the download runs.
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case downloading
            case finished
            case cancelled
            case failed
        }

        var phase: Phase
        /// Download progress, from 0 to 1.
        var progress: Double
        /// When the app last updated the activity. Shown as "updated 12 s ago" to spot when updates stop in the background.
        var updatedAt: Date
    }

    /// Identifier the stop button sends back to the app.
    var downloadID: String
    var title: String
    /// "Image" or "Vidéo HLS".
    var kindLabel: String
}
