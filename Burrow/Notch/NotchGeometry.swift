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
    static let expandedSize = CGSize(width: 620, height: 180)
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

    /// Tercih edilen ekran: önce çentikli dahili ekran, yoksa ana ekran.
    static var preferredNotchScreen: NSScreen? {
        screens.first(where: { $0.hasNotch }) ?? main ?? screens.first
    }
}
