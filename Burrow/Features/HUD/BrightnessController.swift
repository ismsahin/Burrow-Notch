import CoreGraphics
import Foundation
import os

/// Dahili ekran parlaklığı. Apple'ın herkese açık API'si yok; DisplayServices özel çerçevesi
/// çalışma zamanında `dlopen` ile, varsa kullanılır. Yoksa özellik sessizce devre dışı kalır (çökme yok).
final class BrightnessController {
    static let shared = BrightnessController()
    static let step: Float = 1.0 / 16.0

    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getFn: GetFn?
    private let setFn: SetFn?

    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            Logger(subsystem: "com.ismsahin.Burrow", category: "Brightness").notice("DisplayServices yüklenemedi")
            getFn = nil
            setFn = nil
            return
        }
        getFn = dlsym(handle, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: GetFn.self) }
        setFn = dlsym(handle, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetFn.self) }
    }

    var isAvailable: Bool { getFn != nil && setFn != nil }

    private var display: CGDirectDisplayID {
        // Dahili ekranı bul; yoksa ana ekran.
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.first(where: { CGDisplayIsBuiltin($0) != 0 }) ?? CGMainDisplayID()
    }

    func brightness() -> Float? {
        guard let getFn else { return nil }
        var value: Float = 0
        return getFn(display, &value) == 0 ? value : nil
    }

    /// Yeni değeri döndürür; başarısızsa nil.
    @discardableResult
    func adjust(by delta: Float) -> Float? {
        guard let setFn, let current = brightness() else { return nil }
        let target = min(1, max(0, current + delta))
        return setFn(display, target) == 0 ? target : nil
    }
}
