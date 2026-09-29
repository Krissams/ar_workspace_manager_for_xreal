import AppKit
import XCTest
@testable import DisplayManager

final class OutputDisplayHardwareTests: XCTestCase {
    /// Opt-in only: creates the same virtual monitor as the reported failure, then exercises
    /// the actual display recovery API against the connected glasses. Does not render AR.
    @MainActor
    func testDisabledGlassesRecoverAfterVirtualDisplayCreation() async throws {
        guard ProcessInfo.processInfo.environment["XREAL_HARDWARE_RECOVERY_TEST"] == "1" else {
            throw XCTSkip("Requires connected glasses and explicit hardware-test opt-in")
        }
        let screen = try XCTUnwrap(NSScreen.screens.first { $0.localizedName == "Air 2 Pro" })
        let id = try XCTUnwrap(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID)
        let recovery = try XCTUnwrap(OutputDisplayRecovery(displayID: id))
        let service = VirtualDisplayService()
        defer { service.destroyAll() }
        let virtual = service.create(VirtualScreenConfig(name: "Main", width: 2560, height: 1440, hiDPI: true))
        XCTAssertNotNil(virtual)
        var state = OutputStartupRecovery(now: CACurrentMediaTime())
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let resolved = recovery.resolve()
            let ready = resolved.map { CGDisplayIsActive($0) != 0 && recovery.matches($0) } ?? false
            let action = state.advance(now: CACurrentMediaTime(), ready: ready, canRestore: resolved != nil)
            print("HARDWARE output=\(resolved.map(String.init) ?? "missing") online=\(resolved.map { CGDisplayIsOnline($0) } ?? 0) ready=\(ready) action=\(action)")
            if action == .restore, let resolved {
                let result = recovery.restore(resolved)
                print("HARDWARE restore result=\(result.rawValue)")
                XCTAssertEqual(result, .success)
            }
            if action == .start {
                XCTAssertEqual(resolved, id)
                XCTAssertEqual(CGDisplayCopyDisplayMode(id)?.refreshRate, recovery.mode.refreshRate)
                return
            }
            if action == .fail { break }
        }
        XCTFail("Glasses did not recover with virtual monitor still present")
    }
}
