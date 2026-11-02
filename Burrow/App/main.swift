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
app.run()
