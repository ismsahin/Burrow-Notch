import AppKit

/// Saf (test edilebilir) çentik ölçü hesapları. AppKit nesnesine bağımlı değildir.
struct NotchGeometry: Equatable {
    /// Gerçek / sahte çentiğin genişliği ve yüksekliği.
    let notchSize: CGSize
    /// Ekranın tam çerçevesi (global koordinat).
    let screenFrame: CGRect
    /// Ekranda fiziksel çentik var mı?
    let hasPhysicalNotch: Bool

    static let fallbackNotchWidth: CGFloat = 185
    static let fallbackNotchHeight: CGFloat = 32
    static let expandedSize = CGSize(width: 620, height: 196)
    /// Pencere, en büyük içerik + gölge payı kadar sabit boyutludur.
    static let windowSize = CGSize(width: 760, height: 300)

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`
    ///   - leftAuxWidth: `auxiliaryTopLeftArea?.width`
    ///   - rightAuxWidth: `auxiliaryTopRightArea?.width`
    ///   - menuBarHeight: `frame.maxY - visibleFrame.maxY`
    static func make(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        leftAuxWidth: CGFloat?,
        rightAuxWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) -> NotchGeometry {
        if safeAreaTop > 0, let left = leftAuxWidth, let right = rightAuxWidth {
            let width = max(0, screenFrame.width - left - right)
            if width > 0 {
                return NotchGeometry(
                    notchSize: CGSize(width: width, height: safeAreaTop),
                    screenFrame: screenFrame,
                    hasPhysicalNotch: true
                )
            }
        }
        let height = menuBarHeight > 0 ? menuBarHeight : fallbackNotchHeight
        return NotchGeometry(
            notchSize: CGSize(width: fallbackNotchWidth, height: height),
            screenFrame: screenFrame,
            hasPhysicalNotch: false
        )
    }

    /// Pencerenin ekrandaki çerçevesi: üst-orta hizalı.
    var windowFrame: CGRect {
        let size = Self.windowSize
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Verilen içerik boyutu için ekrandaki üst-orta dikdörtgen (fare isabeti için).
    func topCenteredRect(size: CGSize, padding: CGFloat = 0) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2 - padding,
            y: screenFrame.maxY - size.height - padding,
            width: size.width + padding * 2,
            height: size.height + padding
        )
    }
}

extension NotchGeometry {
    /// İmlecin dikdörtgene yakınlığı: içindeyse 1, `radius` ve ötesinde 0, arada doğrusal.
    /// Yalnızca yanlardan ve alttan yaklaşma sayılır (üst kenar ekranın tepesi).
    static func proximity(of point: CGPoint, to rect: CGRect, radius: CGFloat) -> Double {
        guard radius > 0 else { return rect.contains(point) ? 1 : 0 }
        let dx = max(0, max(rect.minX - point.x, point.x - rect.maxX))
        let dy = max(0, rect.minY - point.y)
        let distance = (dx * dx + dy * dy).squareRoot()
        return Double(max(0, 1 - distance / radius))
    }
}

/// Ekran seçimi için AppKit'ten bağımsız tanım (test edilebilir).
struct ScreenDescriptor: Equatable {
    let id: CGDirectDisplayID
    let hasNotch: Bool
    let isPrimary: Bool
}

enum DisplaySelector {
    static func select(_ mode: DisplayMode, from screens: [ScreenDescriptor]) -> [CGDirectDisplayID] {
        let primary = screens.first(where: \.isPrimary) ?? screens.first
        switch mode {
        case .all:
            return screens.map(\.id)
        case .primary:
            return primary.map { [$0.id] } ?? []
        case .notched:
            let notched = screens.filter(\.hasNotch)
            if !notched.isEmpty { return notched.map(\.id) }
            return primary.map { [$0.id] } ?? []
        }
    }
}

extension NSScreen {
    var notchGeometry: NotchGeometry {
        NotchGeometry.make(
            screenFrame: frame,
            safeAreaTop: safeAreaInsets.top,
            leftAuxWidth: auxiliaryTopLeftArea?.width,
            rightAuxWidth: auxiliaryTopRightArea?.width,
            menuBarHeight: frame.maxY - visibleFrame.maxY
        )
    }

    var hasNotch: Bool { safeAreaInsets.top > 0 }

    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Not: `NSScreen.main` odaktaki pencerenin ekranıdır ve değişir; birincil (menü çubuklu) ekran `screens.first`'tür.
    static func screens(for mode: DisplayMode) -> [NSScreen] {
        let all = screens
        let descriptors = all.enumerated().compactMap { index, screen in
            screen.displayID.map { ScreenDescriptor(id: $0, hasNotch: screen.hasNotch, isPrimary: index == 0) }
        }
        let ids = DisplaySelector.select(mode, from: descriptors)
        return all.filter { screen in screen.displayID.map(ids.contains) ?? false }
    }
}
