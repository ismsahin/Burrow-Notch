import Combine
import AudioToolbox
import CoreAudio
import Foundation

/// Varsayılan çıkış aygıtının sesini CoreAudio dinleyicileriyle izler ve ayarlar (izin gerektirmez).
@MainActor
final class VolumeController: ObservableObject {
    @Published private(set) var volume: Double = 0
    @Published private(set) var isMuted = false
    /// Ses ya da sessiz durumu değiştiğinde (kullanıcı veya biz).
    let changes = PassthroughSubject<(volume: Double, muted: Bool), Never>()

    static let step: Double = 1.0 / 16.0

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private let listenerQueue = DispatchQueue(label: "com.ismsahin.Burrow.volume")
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?

    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    init() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.attachToDefaultDevice() }
        }
        defaultDeviceListener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, listenerQueue, listener)
        attachToDefaultDevice()
    }

    // MARK: - Ayar

    /// Aygıt yazılımsal ses denetimini destekliyor mu? (HDMI/DisplayPort/aggregate genelde hayır)
    var canSetVolume: Bool { Self.isSettable(deviceID, &Self.volumeAddress) }

    /// - Returns: Başarılıysa true. false ise tuş sisteme bırakılmalı.
    @discardableResult
    func adjust(by delta: Double) -> Bool {
        guard canSetVolume else { return false }
        if isMuted, delta > 0 { setMuted(false) }
        return setVolume(volume + delta)
    }

    @discardableResult
    func setVolume(_ value: Double) -> Bool {
        var scalar = Float32(min(1, max(0, value)))
        let size = UInt32(MemoryLayout<Float32>.size)
        let ok = AudioObjectSetPropertyData(deviceID, &Self.volumeAddress, 0, nil, size, &scalar) == noErr
        if ok { readState(emit: true) }
        return ok
    }

    @discardableResult
    func toggleMute() -> Bool { setMuted(!isMuted) }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard Self.isSettable(deviceID, &Self.muteAddress) else { return false }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let ok = AudioObjectSetPropertyData(deviceID, &Self.muteAddress, 0, nil, size, &value) == noErr
        if ok { readState(emit: true) }
        return ok
    }

    private static func isSettable(_ device: AudioObjectID, _ address: inout AudioObjectPropertyAddress) -> Bool {
        guard device != kAudioObjectUnknown, AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    // MARK: - İzleme

    private func attachToDefaultDevice() {
        detachDeviceListeners()
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, 0, nil, &size, &id) == noErr else { return }
        deviceID = id

        let onVolume: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.readState(emit: true) }
        }
        volumeListener = onVolume
        AudioObjectAddPropertyListenerBlock(id, &Self.volumeAddress, listenerQueue, onVolume)

        if AudioObjectHasProperty(id, &Self.muteAddress) {
            let onMute: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                Task { @MainActor in self?.readState(emit: true) }
            }
            muteListener = onMute
            AudioObjectAddPropertyListenerBlock(id, &Self.muteAddress, listenerQueue, onMute)
        }
        readState(emit: false)
    }

    private func detachDeviceListeners() {
        guard deviceID != kAudioObjectUnknown else { return }
        if let volumeListener {
            AudioObjectRemovePropertyListenerBlock(deviceID, &Self.volumeAddress, listenerQueue, volumeListener)
        }
        if let muteListener {
            AudioObjectRemovePropertyListenerBlock(deviceID, &Self.muteAddress, listenerQueue, muteListener)
        }
        volumeListener = nil
        muteListener = nil
    }

    private func readState(emit: Bool) {
        var scalar: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let volumeOK = AudioObjectGetPropertyData(deviceID, &Self.volumeAddress, 0, nil, &size, &scalar) == noErr

        var mute: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        let muteOK = AudioObjectHasProperty(deviceID, &Self.muteAddress)
            && AudioObjectGetPropertyData(deviceID, &Self.muteAddress, 0, nil, &size, &mute) == noErr

        let newVolume = volumeOK ? Double(scalar) : volume
        let newMuted = muteOK ? mute != 0 : false
        let changed = abs(newVolume - volume) > 0.001 || newMuted != isMuted
        volume = newVolume
        isMuted = newMuted
        if emit, changed { changes.send((newVolume, newMuted)) }
    }
}
