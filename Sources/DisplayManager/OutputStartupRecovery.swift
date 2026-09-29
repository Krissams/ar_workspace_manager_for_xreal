/// Bounded recovery while macOS restores a display set after virtual-display creation.
/// Kept independent of CoreGraphics so reconnect/timeout sequences can be regression-tested.
public struct OutputStartupRecovery {
    public enum Action: Equatable { case arrange, start, restore, wait, fail }
    private let deadline: Double
    public private(set) var attempts = 0
    private var arranged = false

    public init(now: Double) { deadline = now + 8 }

    public mutating func advance(now: Double, ready: Bool, canRestore: Bool) -> Action {
        if ready {
            if !arranged { arranged = true; return .arrange }
            return .start
        }
        if now >= deadline { return .fail }
        if canRestore && attempts < 2 { attempts += 1; return .restore }
        return .wait
    }
}
