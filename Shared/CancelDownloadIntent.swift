import AppIntents

/// Cancels a download from the stop button of the Live Activity.
///
/// The file is compiled in the app and in the widget extension, because the widget needs the type to build the button.
/// As a `LiveActivityIntent`, the system runs `perform()` in the app process (and launches the app in the background
/// if needed), so only the app build, flagged `MAIN_APP`, actually cancels the download.
struct CancelDownloadIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Annuler le téléchargement"
    static let isDiscoverable = false

    @Parameter(title: "Téléchargement")
    var downloadID: String

    init() {}

    init(downloadID: String) {
        self.downloadID = downloadID
    }

    func perform() async throws -> some IntentResult {
        #if MAIN_APP
        await DownloadController.shared.cancel(downloadID: downloadID, source: .liveActivity)
        #endif
        return .result()
    }
}
