@preconcurrency import AVFoundation
import Combine
import SwiftUI

/// Ön kamera aynası. Oturum yalnızca ayna görünürken çalışır; çentik kapanınca kamera kapanır (yeşil ışık söner).
@MainActor
final class CameraMirror: ObservableObject {
    enum State: Equatable { case off, starting, running, denied, unavailable }

    @Published private(set) var state: State = .off
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ismsahin.Burrow.camera")
    private var configured = false

    func start() {
        guard state == .off else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            state = .starting
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    // İzin penceresi sırasında çentik kapandıysa (stop → .off) kamerayı açma.
                    guard self.state == .starting else { return }
                    if granted { self.run() } else { self.state = .denied }
                }
            }
        default:
            state = .denied
        }
    }

    func stop() {
        guard state == .running || state == .starting else { return }
        state = .off
        let session = session
        sessionQueue.async { if session.isRunning { session.stopRunning() } }
    }

    func toggle() { state == .running ? stop() : start() }

    private func run() {
        state = .starting
        let session = session
        let needsConfig = !configured
        configured = true
        sessionQueue.async {
            if needsConfig {
                session.beginConfiguration()
                session.sessionPreset = .medium
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(for: .video)
                if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                    session.addInput(input)
                }
                session.commitConfiguration()
            }
            let hasInput = !session.inputs.isEmpty
            if hasInput { session.startRunning() }
            Task { @MainActor in
                guard self.state == .starting else {
                    // Bu arada kapatıldıysa kamerayı hemen bırak.
                    self.sessionQueue.async { if session.isRunning { session.stopRunning() } }
                    return
                }
                self.state = hasInput ? .running : .unavailable
            }
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.automaticallyAdjustsVideoMirroring = false
        layer.connection?.isVideoMirrored = true
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
