import Combine
import Foundation
import IOKit.ps

struct BatteryState: Equatable {
    let percent: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let hasBattery: Bool

    static let unknown = BatteryState(percent: 100, isCharging: false, isPluggedIn: true, hasBattery: false)

    /// IOPowerSources sözlüğünden saf ayrıştırma (test edilebilir).
    static func parse(_ description: [String: Any]?) -> BatteryState {
        guard let d = description,
              (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { return .unknown }
        let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = d[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0
        let source = d[kIOPSPowerSourceStateKey] as? String
        return BatteryState(
            percent: min(100, max(0, percent)),
            isCharging: d[kIOPSIsChargingKey] as? Bool ?? false,
            isPluggedIn: source == kIOPSACPowerValue,
            hasBattery: true
        )
    }
}

/// Pil durumunu IOKit bildirimleriyle (yoklama olmadan) izler.
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var state: BatteryState = .unknown
    /// Güç kaynağı takıldı/çıkarıldı olayları.
    let plugEvents = PassthroughSubject<BatteryState, Never>()
    /// Düşük pil eşiği geçildiğinde.
    let lowBatteryEvents = PassthroughSubject<BatteryState, Never>()

    private var runLoopSource: CFRunLoopSource?
    private var lowBatteryWarned = false
    var lowThreshold: Int = 20

    init() {
        state = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
    }

    deinit {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode) }
    }

    private func update() {
        let new = Self.read()
        let old = state
        guard new != old else { return }
        state = new
        guard new.hasBattery else { return }
        if new.isPluggedIn != old.isPluggedIn {
            plugEvents.send(new)
        }
        if !new.isPluggedIn, new.percent <= lowThreshold, !lowBatteryWarned {
            lowBatteryWarned = true
            lowBatteryEvents.send(new)
        }
        if new.isPluggedIn || new.percent > lowThreshold + 5 {
            lowBatteryWarned = false
        }
    }

    private static func read() -> BatteryState {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unknown
        }
        for source in list {
            let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            let parsed = BatteryState.parse(description)
            if parsed.hasBattery { return parsed }
        }
        return .unknown
    }
}
