import CoreGraphics
import ColorSync
import CPrivateDisplay

/// Restores only the output selected before startup, including when a saved display set
/// disables it. Never substitute a different monitor if the original has been unplugged.
public struct OutputDisplayRecovery {
    public let uuid: String
    public let mode: CGDisplayMode

    public init?(displayID: CGDirectDisplayID) {
        guard let uuid = Self.uuid(displayID), let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        self.uuid = uuid
        self.mode = mode
    }

    private static func uuid(_ id: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    public func resolve() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 128)
        var count: UInt32 = 0
        guard VRDGetAllDisplays(UInt32(ids.count), &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { Self.uuid($0) == uuid }
    }

    public func matches(_ id: CGDirectDisplayID) -> Bool {
        guard let current = CGDisplayCopyDisplayMode(id) else { return false }
        return current.ioDisplayModeID == mode.ioDisplayModeID
    }

    /// Restore the selected mode and extended-display state in one session transaction.
    public func restore(_ id: CGDirectDisplayID) -> CGError {
        guard Self.uuid(id) == uuid else { return .illegalArgument }
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success, let config else { return begin }
        let unmirror = CGConfigureDisplayMirrorOfDisplay(config, id, kCGNullDirectDisplay)
        let result = unmirror == .success
            ? CGConfigureDisplayWithDisplayMode(config, id, mode, nil) : unmirror
        guard result == .success else { CGCancelDisplayConfiguration(config); return result }
        return CGCompleteDisplayConfiguration(config, .forSession)
    }
}
