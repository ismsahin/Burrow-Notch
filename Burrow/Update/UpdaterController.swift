import Combine
import Foundation
import Sparkle

/// Sparkle 2 sarmalayıcısı.
/// Güvenlik: her güncelleme EdDSA (ed25519) imzasıyla doğrulanır; genel anahtar Info.plist'te (SUPublicEDKey).
/// Besleme adresi veya anahtar yoksa (yerel geliştirme derlemesi) güncelleyici başlatılmaz.
@MainActor
final class UpdaterController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    let isConfigured: Bool

    private let controller: SPUStandardUpdaterController
    private var cancellable: AnyCancellable?

    init(bundle: Bundle = .main) {
        let feed = (bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String) ?? ""
        let key = (bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String) ?? ""
        isConfigured = feed.hasPrefix("https://") && !key.isEmpty

        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        guard isConfigured else { return }
        do {
            try controller.updater.start()
        } catch {
            NSLog("Burrow: güncelleyici başlatılamadı: \(error.localizedDescription)")
            return
        }
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
    }

    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue; objectWillChange.send() }
    }

    var automaticallyDownloads: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue; objectWillChange.send() }
    }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }

    func checkForUpdates() {
        guard isConfigured else { return }
        controller.checkForUpdates(nil)
    }
}
