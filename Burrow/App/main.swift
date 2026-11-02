import AppKit

// Test çalıştırıcısı uygulamayı barındırırken arayüzü kurmayız (testler saf mantığı sınar).
// Not: `NSClassFromString("XCTestCase")` Debug derlemelerinde de dolu döner; ortam değişkenine bakılır.
let environment = ProcessInfo.processInfo.environment
let isRunningTests = ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"]
    .contains { environment[$0] != nil }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = MainActor.assumeIsolated { AppDelegate() }
if !isRunningTests {
    app.delegate = delegate
}

// SIGTERM/SIGINT (ör. `pkill`, oturum kapanışı) normal kapanışa yönlendirilir; böylece
// applicationWillTerminate çalışır ve arka plandaki medya akış süreci geride kalmaz.
signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
let terminationSources = [SIGTERM, SIGINT].map { sig -> DispatchSourceSignal in
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { NSApp.terminate(nil) }
    source.resume()
    return source
}

app.run()
