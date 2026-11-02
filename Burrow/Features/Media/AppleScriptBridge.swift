import AppKit
import os

/// NSAppleScript çağrılarını tek bir seri kuyrukta çalıştırır (NSAppleScript eşzamanlı kullanıma uygun değildir).
/// Derlenmiş betikler önbelleğe alınır; her betik `with timeout` ile sınırlandırılır ki oynatıcı donarsa biz donmayalım.
final class AppleScriptBridge {
    static let shared = AppleScriptBridge()

    private let queue = DispatchQueue(label: "com.ismsahin.Burrow.applescript", qos: .userInitiated)
    private var cache: [String: NSAppleScript] = [:]
    private let log = Logger(subsystem: "com.ismsahin.Burrow", category: "AppleScript")

    /// Betiği çalıştırır, sonucu ana iş parçacığında döndürür.
    /// - Parameter cacheable: Değişken içerikli (ör. konum atlama) betikler için `false` verin.
    func run(_ source: String, cacheable: Bool = true, completion: ((NSAppleEventDescriptor?) -> Void)? = nil) {
        queue.async { [weak self] in
            let result = self?.execute(source, cacheable: cacheable)
            if let completion {
                DispatchQueue.main.async { completion(result) }
            }
        }
    }

    private func execute(_ source: String, cacheable: Bool) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if let cached = cache[source] {
            script = cached
        } else {
            guard let created = NSAppleScript(source: source) else { return nil }
            var compileError: NSDictionary?
            created.compileAndReturnError(&compileError)
            if let compileError {
                log.error("Derleme hatası: \(compileError, privacy: .public)")
                return nil
            }
            if cacheable { cache[source] = created }
            script = created
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            // -1743: kullanıcı otomasyon iznini vermedi. -600: uygulama kapandı. Sessizce geçmeyiz, loglarız.
            log.notice("Betik hatası \(code): \(error[NSAppleScript.errorMessage] as? String ?? "?", privacy: .public)")
            return nil
        }
        return result
    }
}

extension NSAppleEventDescriptor {
    /// Liste tanımlayıcısını metin dizisine çevirir (AppleScript listeleri 1 tabanlıdır).
    var stringList: [String] {
        guard numberOfItems > 0 else { return [] }
        return (1...numberOfItems).map { atIndex($0)?.stringValue ?? "" }
    }
}
