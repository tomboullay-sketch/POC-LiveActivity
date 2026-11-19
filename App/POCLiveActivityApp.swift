import SwiftUI
import UIKit

@main
struct POCLiveActivityApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(controller: .shared)
        }
    }
}

/// Reconnects the background downloads at launch and receives their events when iOS relaunches the app for them.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { await DownloadController.shared.restoreAfterLaunch() }
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadController.shared.handleBackgroundEvents(for: identifier, completionHandler: completionHandler)
    }
}
