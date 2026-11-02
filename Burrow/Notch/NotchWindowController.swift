import AppKit
import Combine
import SwiftUI

/// Kenarlıksız, odak çalmayan, tüm masaüstlerinde görünen panel.
final class NotchPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        level = .statusBar + 8
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Yalnızca görünen çentik şeklinin içinde tıklama kabul eden barındırma görünümü.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var hitRect: () -> CGRect = { .infinite }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard hitRect().contains(local) else { return nil }
        return super.hitTest(point)
    }
}

/// Bir ekran için panel + fare/sürükleme/kaydırma takibi.
@MainActor
final class NotchWindowController: NSObject {
    let viewModel: NotchViewModel
    private(set) var screen: NSScreen
    private let panel: NotchPanel
    private var monitors: [Any] = []
    private var hoverWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount
    private var isFileDragging = false
    private var scrollAccumulator = CGSize.zero
    private var scrollHandled = false
    private var bag = Set<AnyCancellable>()

    private static let hoverPadding: CGFloat = 6
    private static let dragActivationPadding: CGFloat = 40
    private static let collapseDelay: TimeInterval = 0.12
    private static let swipeThreshold: CGFloat = 50

    init(screen: NSScreen, services: AppServices) {
        self.screen = screen
        let geometry = screen.notchGeometry
        viewModel = NotchViewModel(geometry: geometry, services: services)
        panel = NotchPanel(frame: geometry.windowFrame)
        super.init()

        let root = NotchRootView(viewModel: viewModel, services: services)
        let hosting = NotchHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: geometry.windowFrame.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.acceptsMouseMovedEvents = true
        hosting.hitRect = { [weak self, weak hosting] in
            guard let self, let hosting, let window = hosting.window else { return .zero }
            let screenRect = self.activeRect
            let windowRect = window.convertFromScreen(screenRect)
            return hosting.convert(windowRect, from: nil)
        }
        panel.setFrame(geometry.windowFrame, display: true)
        panel.orderFrontRegardless()

        installMonitors()
        viewModel.$isExpanded
            .combineLatest(services.activity.$current)
            .sink { [weak self] _, _ in self?.updateMouseInteractivity() }
            .store(in: &bag)
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        hoverWork?.cancel()
        collapseWork?.cancel()
        panel.orderOut(nil)
        panel.close()
    }

    func updateScreen(_ screen: NSScreen) {
        self.screen = screen
        let geometry = screen.notchGeometry
        viewModel.updateGeometry(geometry)
        panel.setFrame(geometry.windowFrame, display: true)
    }

    // MARK: - İsabet alanları (ekran koordinatı)

    private var compactRect: CGRect {
        let size = viewModel.compactSize(for: viewModel.services.activity.current)
        return viewModel.geometry.topCenteredRect(size: size, padding: Self.hoverPadding)
    }

    private var expandedRect: CGRect {
        viewModel.geometry.topCenteredRect(size: viewModel.expandedSize, padding: Self.hoverPadding)
    }

    private var activeRect: CGRect { viewModel.isExpanded ? expandedRect : compactRect }

    // MARK: - Olay izleme

    private func installMonitors() {
        let mouseMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseMask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouse(event) }
        }) { monitors.append(global) }

        if let local = NSEvent.addLocalMonitorForEvents(matching: mouseMask.union(.scrollWheel), handler: { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return event }
                if event.type == .scrollWheel, event.window === self.panel {
                    self.handleScroll(event)
                } else {
                    self.handleMouse(event)
                }
                return event
            }
        }) { monitors.append(local) }
    }

    private func handleMouse(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown:
            dragChangeCount = NSPasteboard(name: .drag).changeCount
            isFileDragging = false
        case .leftMouseUp:
            isFileDragging = false
            scheduleCollapseIfNeeded(location)
            updateMouseInteractivity()
            return
        case .leftMouseDragged:
            handleDrag(location)
            updateMouseInteractivity()
            return
        default:
            break
        }
        handleHover(location)
    }

    private func handleHover(_ location: CGPoint) {
        refreshDragState()
        guard screen.frame.contains(location) || activeRect.contains(location) else {
            cancelHover()
            scheduleCollapseIfNeeded(location)
            updateMouseInteractivity()
            return
        }
        if viewModel.isExpanded {
            if expandedRect.contains(location) {
                cancelCollapse()
            } else {
                scheduleCollapseIfNeeded(location)
            }
            updateMouseInteractivity()
            return
        }
        if compactRect.contains(location) {
            setInteractive(true)
            guard viewModel.services.settings.hoverToExpand, hoverWork == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.hoverWork = nil
                if self.compactRect.contains(NSEvent.mouseLocation) { self.expand() }
            }
            hoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + viewModel.services.settings.hoverDelay, execute: work)
        } else {
            cancelHover()
            updateMouseInteractivity()
        }
    }

    private func handleDrag(_ location: CGPoint) {
        let pasteboard = NSPasteboard(name: .drag)
        if !isFileDragging, pasteboard.changeCount != dragChangeCount,
           pasteboard.types?.contains(.fileURL) == true {
            isFileDragging = true
        }
        guard isFileDragging, viewModel.services.settings.enableShelf else { return }
        let zone = viewModel.geometry.topCenteredRect(
            size: viewModel.isExpanded ? viewModel.expandedSize : viewModel.compactSize(for: viewModel.services.activity.current),
            padding: Self.dragActivationPadding
        )
        if zone.contains(location) {
            cancelCollapse()
            expand(tab: .shelf)
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard viewModel.services.settings.swipeGestures else { return }
        if event.phase == .began || event.phase == .mayBegin {
            scrollAccumulator = .zero
            scrollHandled = false
        }
        guard !scrollHandled else {
            if event.phase == .ended || event.phase == .cancelled { scrollHandled = false }
            return
        }
        scrollAccumulator.width += event.scrollingDeltaX
        scrollAccumulator.height += event.scrollingDeltaY
        let media = viewModel.services.media

        if abs(scrollAccumulator.width) > Self.swipeThreshold, abs(scrollAccumulator.width) > abs(scrollAccumulator.height) {
            scrollHandled = true
            guard media.info != nil else { return }
            // Doğal kaydırmada sola kaydırma deltaX < 0 → sonraki parça
            let towardsNext = event.isDirectionInvertedFromDevice ? scrollAccumulator.width < 0 : scrollAccumulator.width > 0
            towardsNext ? media.next() : media.previous()
            haptic()
        } else if abs(scrollAccumulator.height) > Self.swipeThreshold {
            scrollHandled = true
            let down = event.isDirectionInvertedFromDevice ? scrollAccumulator.height > 0 : scrollAccumulator.height < 0
            if down, !viewModel.isExpanded { expand() }
            if !down, viewModel.isExpanded { viewModel.collapse() }
        }
        if event.phase == .ended || event.phase == .cancelled {
            scrollAccumulator = .zero
            scrollHandled = false
        }
    }

    // MARK: - Durum değişimleri

    func expand(tab: NotchTab? = nil) {
        cancelHover()
        cancelCollapse()
        setInteractive(true)
        viewModel.expand(tab: tab)
    }

    func toggle() {
        viewModel.isExpanded ? viewModel.collapse() : expand()
    }

    /// Sürükleme oturumları mouseUp olayını yutabilir; fiziksel tuş durumuna bakarak bayrağı düzelt.
    private func refreshDragState() {
        if isFileDragging, NSEvent.pressedMouseButtons & 1 == 0 { isFileDragging = false }
    }

    private func scheduleCollapseIfNeeded(_ location: CGPoint) {
        refreshDragState()
        guard viewModel.isExpanded, !isFileDragging, !expandedRect.contains(location) else { return }
        guard collapseWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWork = nil
            self.refreshDragState()
            if !self.expandedRect.contains(NSEvent.mouseLocation), !self.isFileDragging {
                self.viewModel.collapse()
            }
            self.updateMouseInteractivity()
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.collapseDelay, execute: work)
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }

    private func cancelHover() {
        hoverWork?.cancel()
        hoverWork = nil
    }

    /// Panel yalnızca imleç görünen şeklin içindeyken (veya dosya sürüklenirken) tıklama alır;
    /// böylece şeffaf kenarlar menü çubuğunu ve alttaki pencereleri asla engellemez.
    private func updateMouseInteractivity() {
        let inside = activeRect.contains(NSEvent.mouseLocation)
        setInteractive(inside || (isFileDragging && viewModel.isExpanded))
    }

    private func setInteractive(_ interactive: Bool) {
        if panel.ignoresMouseEvents == interactive { panel.ignoresMouseEvents = !interactive }
    }

    private func haptic() {
        guard viewModel.services.settings.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
}
