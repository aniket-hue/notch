import CoreAudio
import Foundation

@MainActor
final class MicService: ObservableObject {
    @Published private(set) var muted = false
    @Published private(set) var available = false

    private var device: AudioDeviceID = 0
    private var savedVolume: Float32 = 1.0

    init() {
        refresh()
    }

    func refresh() {
        guard let d = Self.defaultInputDevice() else {
            available = false
            return
        }
        device = d
        available = true
        muted = Self.readMuted(d)
    }

    func toggle() {
        refresh()
        guard available else { return }
        setMuted(!muted)
    }

    private func setMuted(_ on: Bool) {
        if Self.setMuteProperty(device, on) {
            muted = on
            return
        }
        if on {
            savedVolume = Self.inputVolume(device) ?? 1.0
            _ = Self.setInputVolume(device, 0)
        } else {
            _ = Self.setInputVolume(device, savedVolume > 0.001 ? savedVolume : 1.0)
        }
        muted = on
    }

    // MARK: - CoreAudio

    private static func defaultInputDevice() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain,
        )
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return status == noErr && id != 0 ? id : nil
    }

    private static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain,
        )
    }

    private static func readMuted(_ device: AudioDeviceID) -> Bool {
        var addr = muteAddress()
        if AudioObjectHasProperty(device, &addr) {
            var value = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr {
                return value != 0
            }
        }
        if let volume = inputVolume(device) { return volume < 0.001 }
        return false
    }

    private static func setMuteProperty(_ device: AudioDeviceID, _ on: Bool) -> Bool {
        var addr = muteAddress()
        var settable = DarwinBoolean(false)
        guard AudioObjectHasProperty(device, &addr),
              AudioObjectIsPropertySettable(device, &addr, &settable) == noErr, settable.boolValue
        else { return false }
        var value = UInt32(on ? 1 : 0)
        return AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    private static let volumeElements: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]

    private static func volumeAddress(_ element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: element,
        )
    }

    private static func inputVolume(_ device: AudioDeviceID) -> Float32? {
        for element in volumeElements {
            var addr = volumeAddress(element)
            guard AudioObjectHasProperty(device, &addr) else { continue }
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr {
                return value
            }
        }
        return nil
    }

    @discardableResult
    private static func setInputVolume(_ device: AudioDeviceID, _ volume: Float32) -> Bool {
        var ok = false
        for element in volumeElements {
            var addr = volumeAddress(element)
            var settable = DarwinBoolean(false)
            guard AudioObjectHasProperty(device, &addr),
                  AudioObjectIsPropertySettable(device, &addr, &settable) == noErr, settable.boolValue
            else { continue }
            var value = volume
            if AudioObjectSetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr {
                ok = true
            }
        }
        return ok
    }
}
