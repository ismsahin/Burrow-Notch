import Combine
import CoreBluetooth
import IOBluetooth

/// Bluetooth cihaz bağlanma/kopma olaylarını yayınlar (kulaklık, klavye, fare...).
///
/// Önemli: `IOBluetoothDevice.register(forConnectNotifications:)` izin henüz verilmemişse, kullanıcı
/// Bluetooth izin penceresini yanıtlayana kadar **ana iş parçacığını kilitler** (uygulama donar).
/// Bu yüzden izin önce CoreBluetooth ile eşzamansız istenir; kayıt yalnızca izin verilince yapılır.
@MainActor
final class BluetoothMonitor: NSObject {
    struct Event: Equatable {
        let name: String
        let connected: Bool
    }

    let events = PassthroughSubject<Event, Never>()
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var startedAt = Date()
    private var wantsRunning = false
    /// Yalnızca izin istemek için (tarama yapılmaz).
    private var permissionManager: CBCentralManager?
    /// Kayıt anında zaten bağlı cihazlar için gelen ilk bildirimleri yut.
    private static let registrationGrace: TimeInterval = 3

    func start() {
        wantsRunning = true
        switch CBManager.authorization {
        case .allowedAlways:
            register()
        case .notDetermined:
            // Pencere eşzamansız açılır; yanıt `centralManagerDidUpdateState` ile gelir.
            if permissionManager == nil {
                permissionManager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
            }
        default:
            break // Reddedildi/kısıtlı: sessizce kapalı kal
        }
    }

    func stop() {
        wantsRunning = false
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
    }

    private func register() {
        guard wantsRunning, connectNotification == nil, CBManager.authorization == .allowedAlways else { return }
        startedAt = Date()
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? UUID().uuidString
        disconnectNotifications[address]?.unregister()
        disconnectNotifications[address] = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        guard Date().timeIntervalSince(startedAt) > Self.registrationGrace else { return }
        events.send(Event(name: device.name ?? "Bluetooth cihazı", connected: true))
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let address = device.addressString {
            disconnectNotifications.removeValue(forKey: address)?.unregister()
        }
        events.send(Event(name: device.name ?? "Bluetooth cihazı", connected: false))
    }
}

extension BluetoothMonitor: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            guard CBManager.authorization != .notDetermined else { return }
            register()
            // Yöneticiyi kendi geri çağrısı içinde serbest bırakma; bir sonraki turda bırak.
            DispatchQueue.main.async { [weak self] in self?.permissionManager = nil }
        }
    }
}
