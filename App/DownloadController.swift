import ActivityKit
import AVFoundation
import Foundation
import ImageIO
import UIKit

/// Runs one download at a time and mirrors its progress in our Live Activity.
///
/// Every session is a background session, like the real D2Go: downloads go on when the app is suspended,
/// but the app no longer receives progress, so it can't update the Live Activity until it comes back.
@MainActor
final class DownloadController: NSObject, ObservableObject {
    enum CancelSource {
        case app
        case liveActivity

        var label: String {
            switch self {
            case .app: "depuis l'app"
            case .liveActivity: "depuis notre Live Activity"
            }
        }
    }

    struct RunningDownload {
        let id: String
        let title: String
        var progress: Double
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let text: String
    }

    typealias Phase = DownloadActivityAttributes.ContentState.Phase

    static let shared = DownloadController()

    @Published private(set) var running: RunningDownload?
    @Published private(set) var image: UIImage?
    @Published private(set) var log: [LogEntry] = []
    @Published var discretionaryHLS = false

    private var progressObservation: NSKeyValueObservation?
    private var lastActivityUpdate = Date.distantPast
    private var cancelledIDs: Set<String> = []
    private var hlsLocations: [String: URL] = [:]
    private var backgroundCompletionHandlers: [String: () -> Void] = [:]

    private lazy var fileSession = URLSession(
        configuration: Self.backgroundConfiguration(POCConfig.fileSessionID, discretionary: false),
        delegate: self,
        delegateQueue: .main
    )
    private lazy var hlsSession = AVAssetDownloadURLSession(
        configuration: Self.backgroundConfiguration(POCConfig.hlsSessionID, discretionary: false),
        assetDownloadDelegate: self,
        delegateQueue: .main
    )
    private lazy var discretionaryHLSSession = AVAssetDownloadURLSession(
        configuration: Self.backgroundConfiguration(POCConfig.discretionaryHLSSessionID, discretionary: true),
        assetDownloadDelegate: self,
        delegateQueue: .main
    )

    private var allSessions: [URLSession] {
        [fileSession, hlsSession, discretionaryHLSSession]
    }

    // MARK: - Actions

    func downloadImage() {
        let task = fileSession.downloadTask(with: POCConfig.imageURL)
        start(task, title: POCConfig.imageTitle, kindLabel: "Image", logDetail: "URLSessionDownloadTask")
    }

    func downloadHLS() {
        let asset = AVURLAsset(url: POCConfig.hlsURL)
        let configuration = AVAssetDownloadConfiguration(asset: asset, title: POCConfig.hlsTitle)
        let session = discretionaryHLS ? discretionaryHLSSession : hlsSession
        let task = session.makeAssetDownloadTask(downloadConfiguration: configuration)
        let detail = discretionaryHLS ? "AVAssetDownloadTask, isDiscretionary = true" : "AVAssetDownloadTask, isDiscretionary = false"
        start(task, title: POCConfig.hlsTitle, kindLabel: "Vidéo", logDetail: detail)
    }

    /// Cancels the download, from the app or from the stop button of the Live Activity.
    func cancel(downloadID: String, source: CancelSource) async {
        cancelledIDs.insert(downloadID)
        addLog("■ Annulé \(source.label)")
        for session in allSessions {
            for task in await session.allTasks where task.taskDescription == downloadID {
                task.cancel()
            }
        }
        endActivity(downloadID: downloadID, phase: .cancelled, progress: progress(of: downloadID))
        clearRunning(downloadID)
    }

    // MARK: - App lifecycle

    /// Reconnects the background sessions and ends the Live Activities whose download no longer exists,
    /// for instance after the app was force-quit (iOS then cancels its background downloads).
    func restoreAfterLaunch() async {
        var liveIDs = Set<String>()
        for session in allSessions {
            for task in await session.allTasks {
                if let id = task.taskDescription { liveIDs.insert(id) }
            }
        }
        for activity in Activity<DownloadActivityAttributes>.activities where !liveIDs.contains(activity.attributes.downloadID) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func handleBackgroundEvents(for identifier: String, completionHandler: @escaping () -> Void) {
        backgroundCompletionHandlers[identifier] = completionHandler
        _ = allSessions
    }

    // MARK: - Download

    private func start(_ task: URLSessionTask, title: String, kindLabel: String, logDetail: String) {
        let id = UUID().uuidString
        task.taskDescription = id
        running = RunningDownload(id: id, title: title, progress: 0)
        image = nil
        addLog("▶︎ \(title) lancé (\(logDetail))")

        // URLSessionTask.progress covers both the image download and the HLS download.
        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor in self?.didProgress(fraction, downloadID: id) }
        }
        startActivity(downloadID: id, title: title, kindLabel: kindLabel)
        task.resume()
    }

    private func didProgress(_ fraction: Double, downloadID: String) {
        guard running?.id == downloadID else { return }
        running?.progress = fraction
        // At most one update per second: ActivityKit throttles activities updated too often.
        guard Date().timeIntervalSince(lastActivityUpdate) >= 1 else { return }
        lastActivityUpdate = Date()
        updateActivity(downloadID: downloadID, progress: fraction)
    }

    private func didComplete(downloadID: String, error: Error?) {
        let progress = progress(of: downloadID)
        if let location = hlsLocations.removeValue(forKey: downloadID) {
            // The POC keeps no video on the phone.
            try? FileManager.default.removeItem(at: location)
        }

        if let error = error as NSError? {
            if cancelledIDs.remove(downloadID) != nil {
                // Already handled by cancel(downloadID:source:).
            } else if error.domain == NSCocoaErrorDomain, error.code == NSUserCancelledError {
                addLog("■ Annulé par la Live Activity native d'iOS (\(error.domain) \(error.code))")
                endActivity(downloadID: downloadID, phase: .cancelled, progress: progress)
            } else {
                addLog("✕ Échec : \(error.domain) \(error.code), \(error.localizedDescription)")
                endActivity(downloadID: downloadID, phase: .failed, progress: progress)
            }
        } else {
            addLog("✓ Terminé")
            endActivity(downloadID: downloadID, phase: .finished, progress: 1)
        }
        clearRunning(downloadID)
    }

    private func clearRunning(_ downloadID: String) {
        guard running?.id == downloadID else { return }
        running = nil
        progressObservation = nil
    }

    private func progress(of downloadID: String) -> Double {
        running?.id == downloadID ? running?.progress ?? 0 : 0
    }

    // MARK: - Live Activity

    private func startActivity(downloadID: String, title: String, kindLabel: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            addLog("⚠️ Live Activities désactivées dans Réglages")
            return
        }
        let attributes = DownloadActivityAttributes(downloadID: downloadID, title: title, kindLabel: kindLabel)
        let state = DownloadActivityAttributes.ContentState(phase: .downloading, progress: 0, updatedAt: .now)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            addLog("Notre Live Activity démarrée")
        } catch {
            addLog("⚠️ Live Activity refusée : \(error.localizedDescription)")
        }
    }

    private func updateActivity(downloadID: String, progress: Double) {
        let state = DownloadActivityAttributes.ContentState(phase: .downloading, progress: progress, updatedAt: .now)
        for activity in activities(for: downloadID) {
            Task { await activity.update(.init(state: state, staleDate: nil)) }
        }
    }

    private func endActivity(downloadID: String, phase: Phase, progress: Double) {
        let state = DownloadActivityAttributes.ContentState(phase: phase, progress: progress, updatedAt: .now)
        let dismissalPolicy: ActivityUIDismissalPolicy = phase == .cancelled ? .immediate : .default
        for activity in activities(for: downloadID) {
            Task { await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: dismissalPolicy) }
        }
    }

    /// Looks activities up by download, so it still works when iOS relaunched the app in the background.
    private func activities(for downloadID: String) -> [Activity<DownloadActivityAttributes>] {
        Activity<DownloadActivityAttributes>.activities.filter { $0.attributes.downloadID == downloadID }
    }

    // MARK: - Helpers

    private func addLog(_ text: String) {
        let time = Date.now.formatted(date: .omitted, time: .standard)
        log.insert(LogEntry(text: "\(time)  \(text)"), at: 0)
    }

    private static func backgroundConfiguration(_ identifier: String, discretionary: Bool) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.isDiscretionary = discretionary
        configuration.sessionSendsLaunchEvents = true
        return configuration
    }

    /// Decodes a small version of the image: the full one can take hundreds of MB once decoded.
    nonisolated private static func thumbnail(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1200,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

// MARK: - URLSession delegates

// The sessions deliver their callbacks on the main queue, hence `MainActor.assumeIsolated`.
extension DownloadController: URLSessionDownloadDelegate, AVAssetDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // iOS deletes the file when this method returns, so it is read right away.
        let thumbnail = Self.thumbnail(at: location)
        MainActor.assumeIsolated { image = thumbnail }
    }

    @available(iOS 18.0, *)
    nonisolated func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, willDownloadTo location: URL) {
        guard let id = assetDownloadTask.taskDescription else { return }
        MainActor.assumeIsolated { hlsLocations[id] = location }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription else { return }
        MainActor.assumeIsolated { didComplete(downloadID: id, error: error) }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }
        MainActor.assumeIsolated {
            backgroundCompletionHandlers.removeValue(forKey: identifier)?()
        }
    }
}
