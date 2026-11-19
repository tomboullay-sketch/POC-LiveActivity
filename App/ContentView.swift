import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: DownloadController

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("POC Live Activity avec ActivityKit")
                            .font(.title3.bold())
                        Text("iOS \(UIDevice.current.systemVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Télécharger l'image", systemImage: "photo") {
                    controller.downloadImage()
                }
                Button("Télécharger la vidéo", systemImage: "film") {
                    controller.downloadHLS()
                }
            } header: {
                Text("Lancer un téléchargement")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ne concerne que la vidéo.")
                    Text("**Désactivé** : le téléchargement démarre tout de suite. Sur iOS 27, l'iPhone affiche aussi sa propre Live Activity, en plus de la nôtre.")
                    Text("**Activé** : l'iPhone n'affiche plus la sienne, mais il peut attendre d'être en Wi-Fi et en charge pour télécharger.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Toggle(isOn: $controller.discretionaryHLS) {
                    Text("isDiscretionary")
                        .font(.body.monospaced())
                }
            }
            .disabled(controller.running != nil)

            if let running = controller.running {
                Section("En cours") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(running.title)
                        ProgressView(value: running.progress)
                        Text(running.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Button("Annuler", systemImage: "stop.fill", role: .destructive) {
                        Task { await controller.cancel(downloadID: running.id, source: .app) }
                    }
                }
            }

            if let image = controller.image {
                Section("Image téléchargée") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }

            Section("Journal") {
                if controller.log.isEmpty {
                    Text("Rien pour l'instant")
                        .foregroundStyle(.secondary)
                }
                ForEach(controller.log) { entry in
                    Text(entry.text)
                        .font(.footnote.monospaced())
                }
            }
        }
    }
}
