import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: AppServices!
    private var updater: UpdaterController!
    private let launchAtLogin = LaunchAtLogin()
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else { return }
        services = AppServices()
        updater = UpdaterController()
        launchAtLogin.enableOnFirstLaunch()
        setupStatusItem()
        rebuildWindows()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildWindows() }
            .store(in: &bag)
        services.settings.$showOnAllDisplays
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.rebuildWindows() } }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: .burrowOpenSettings)
            .sink { [weak self] _ in self?.openSettings() }
            .store(in: &bag)
        #if DEBUG
        installDebugHooks()
        #endif
    }

    #if DEBUG
    /// Yalnızca Debug: görsel test için `scripts/debug-notch.sh toggle|shelf|settings`.
    private func installDebugHooks() {
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("com.ismsahin.Burrow.debug"))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                guard let self, let command = note.object as? String else { return }
                switch command {
                case "toggle": self.controllers.values.first?.toggle()
                case "shelf": self.controllers.values.first?.expand(tab: .shelf)
                case "settings": self.openSettings()
                case "hud": self.services.activity.show(.hud(kind: .volume(muted: false), value: 0.6))
                case "charge": self.services.activity.show(.charging(percent: 76, isCharging: true))
                case "device": self.services.activity.show(.device(name: "AirPods Pro", connected: true))
                default: break
                }
            }
            .store(in: &bag)
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        controllers.values.forEach { $0.close() }
        services?.updateKeyTap(enabled: false)
    }

    /// Aynı uygulamanın ikinci kopyası açılırsa (ör. güncelleme sonrası) kendini kapatır.
    private func ensureSingleInstance() -> Bool {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != .current }
        guard others.isEmpty else {
            NSApp.terminate(nil)
            return false
        }
        return true
    }

    // MARK: - Pencereler

    private func rebuildWindows() {
        let targets: [NSScreen]
        if services.settings.showOnAllDisplays {
            targets = NSScreen.screens
        } else {
            targets = NSScreen.preferredNotchScreen.map { [$0] } ?? []
        }
        let wanted = Dictionary(targets.compactMap { s in s.displayID.map { ($0, s) } }, uniquingKeysWith: { a, _ in a })

        for (id, controller) in controllers where wanted[id] == nil {
            controller.close()
            controllers.removeValue(forKey: id)
        }
        for (id, screen) in wanted {
            if let existing = controllers[id] {
                existing.updateScreen(screen)
            } else {
                controllers[id] = NotchWindowController(screen: screen, services: services)
            }
        }
    }

    // MARK: - Menü çubuğu

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule.portrait.tophalf.filled", accessibilityDescription: "Burrow")
            ?? NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Burrow")
        let menu = NSMenu()
        menu.addItem(withTitle: "Çentiği Aç/Kapat", action: #selector(toggleNotch), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Ayarlar…", action: #selector(openSettingsAction), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Güncellemeleri Denetle…", action: #selector(checkUpdates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Burrow'dan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleNotch() {
        controllers.values.first?.toggle()
    }

    @objc private func openSettingsAction() { openSettings() }

    @objc private func checkUpdates() { updater.checkForUpdates() }

    private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: services.settings, services: services, updater: updater, launchAtLogin: launchAtLogin)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Burrow Ayarları"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
