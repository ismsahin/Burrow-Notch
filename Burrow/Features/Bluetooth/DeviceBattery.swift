import Foundation

/// Bluetooth cihaz pil düzeyleri (AirPods: sol/sağ/kutu; diğerleri: tek değer).
struct DeviceBattery: Equatable {
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var main: Int?

    var isEmpty: Bool { left == nil && right == nil && caseLevel == nil && main == nil }

    /// Tek satır özet: "S %80 · D %78 · Kutu %60" veya "%55"
    var summary: String {
        var parts: [String] = []
        if let left, let right, left == right { parts.append("%\(left)") }
        else {
            if let left { parts.append("S %\(left)") }
            if let right { parts.append("D %\(right)") }
        }
        if let caseLevel { parts.append("Kutu %\(caseLevel)") }
        if parts.isEmpty, let main { parts.append("%\(main)") }
        return parts.joined(separator: " · ")
    }

    /// Gösterilecek en düşük kulaklık düzeyi (kutu hariç).
    var lowest: Int? { [left, right, main].compactMap { $0 }.min() }
}

/// `system_profiler SPBluetoothDataType -json` çıktısını okur.
///
/// Neden bu yol: AirPods pil düzeyi için genel bir API yok. `system_profiler` Apple'ın kendi aracıdır,
/// ek izin istemez; yalnızca cihaz bağlandığında ve bağlıyken birkaç dakikada bir, arka planda çalıştırılır.
enum DeviceBatteryReader {
    /// Saf ayrıştırıcı: cihaz adı → pil.
    static func parse(_ data: Data) -> [String: DeviceBattery] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return [:] }
        var result: [String: DeviceBattery] = [:]
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, value) in entry {
                    guard let info = value as? [String: Any] else { continue }
                    let battery = DeviceBattery(
                        left: percent(info["device_batteryLevelLeft"]),
                        right: percent(info["device_batteryLevelRight"]),
                        caseLevel: percent(info["device_batteryLevelCase"]),
                        main: percent(info["device_batteryLevelMain"] ?? info["device_batteryLevel"])
                    )
                    if !battery.isEmpty { result[name] = battery }
                }
            }
        }
        return result
    }

    /// "80%" / "80 %" / 80 → 80
    static func percent(_ value: Any?) -> Int? {
        if let number = value as? Int { return (0...100).contains(number) ? number : nil }
        guard let text = value as? String else { return nil }
        let digits = text.filter(\.isNumber)
        guard let number = Int(digits), (0...100).contains(number) else { return nil }
        return number
    }

    /// Arka planda çalıştırır; sonuç ana iş parçacığında döner. En fazla 8 sn bekler.
    static func read(completion: @escaping @MainActor ([String: DeviceBattery]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            var output = Data()
            do {
                try process.run()
                let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 8, execute: killer)
                output = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                killer.cancel()
            } catch {
                NSLog("Burrow: system_profiler çalıştırılamadı: \(error.localizedDescription)")
            }
            let parsed = parse(output)
            DispatchQueue.main.async { MainActor.assumeIsolated { completion(parsed) } }
        }
    }
}
