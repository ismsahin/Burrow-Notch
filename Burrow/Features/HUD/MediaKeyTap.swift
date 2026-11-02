import AppKit
import os

/// Ses/parlaklık tuşlarını yakalayıp sistem HUD'u yerine Burrow HUD'unu göstermek için CGEventTap.
/// Erişilebilirlik izni gerektirir; izin yoksa hiç kurulmaz ve sistem davranışı aynen kalır.
final class MediaKeyTap {
    enum Key: Equatable {
        case volumeUp, volumeDown, mute, brightnessUp, brightnessDown

        /// NX_KEYTYPE_* değerleri (IOKit/hidsystem/ev_keymap.h)
        init?(code: Int) {
            switch code {
            case 0: self = .volumeUp
            case 1: self = .volumeDown
            case 7: self = .mute
            case 2: self = .brightnessUp
            case 3: self = .brightnessDown
            default: return nil
            }
        }
    }

    /// Tuşu işledik mi? true dönerse olay sisteme iletilmez.
    typealias Handler = (_ key: Key, _ fine: Bool) -> Bool

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let handler: Handler
    private var swallowedKeys: Set<Int> = []
    private let log = Logger(subsystem: "com.ismsahin.Burrow", category: "MediaKeyTap")

    private static let systemDefinedType: UInt32 = 14
    private static let mediaKeySubtype: Int16 = 8

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    deinit { stop() }

    static var hasPermission: Bool { AXIsProcessTrusted() }

    /// Sistem izin penceresini açar (kullanıcı onay verene kadar tap kurulmaz).
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasPermission else { return false }
        let mask = CGEventMask(1) << CGEventMask(Self.systemDefinedType)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: userInfo
        ) else {
            log.error("Event tap oluşturulamadı")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Sistem, geri çağrı yavaş kalırsa tap'i kapatır; yeniden açıyoruz.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == Self.systemDefinedType,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == Self.mediaKeySubtype else {
            return Unmanaged.passUnretained(event)
        }
        let data = nsEvent.data1
        let code = (data & 0xFFFF_0000) >> 16
        let flags = data & 0x0000_FFFF
        let isKeyDown = ((flags & 0xFF00) >> 8) == 0xA
        guard let key = Key(code: code) else { return Unmanaged.passUnretained(event) }

        // Option+Shift ile ince adım (macOS ile aynı davranış).
        let fine = nsEvent.modifierFlags.contains(.option) && nsEvent.modifierFlags.contains(.shift)
        if isKeyDown {
            let handled = handler(key, fine)
            if handled { swallowedKeys.insert(code) } else { swallowedKeys.remove(code) }
            return handled ? nil : Unmanaged.passUnretained(event)
        }
        // Tuş bırakma: yalnızca basışını yuttuğumuz tuşun bırakılmasını da yutarız.
        return swallowedKeys.remove(code) != nil ? nil : Unmanaged.passUnretained(event)
    }
}
