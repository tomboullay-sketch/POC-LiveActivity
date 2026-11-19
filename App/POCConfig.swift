import Foundation

/// What the POC downloads. Change the URLs here to test other files.
enum POCConfig {
    /// A ~40 MB Hubble image (ESA/Hubble, CC BY 4.0), downloaded with a plain `URLSessionDownloadTask`.
    static let imageURL = URL(string: "https://cdn.esahubble.org/archives/images/large/heic0506a.jpg")!
    static let imageTitle = "Image Hubble (40 Mo)"

    /// Apple's public HLS test stream, downloaded with an `AVAssetDownloadTask` like the real D2Go.
    static let hlsURL = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!
    static let hlsTitle = "Vidéo Bipbop"

    static let fileSessionID = "poc.session.file"
    static let hlsSessionID = "poc.session.hls"
    static let discretionaryHLSSessionID = "poc.session.hls.discretionary"
}
