import XCTest
@testable import DisplayManager

final class OutputStartupRecoveryTests: XCTestCase {
    func testSavedModeChangeRecoversBeforeRendering() {
        var recovery = OutputStartupRecovery(now: 0)
        XCTAssertEqual(recovery.advance(now: 1, ready: false, canRestore: true), .restore)
        XCTAssertEqual(recovery.advance(now: 2, ready: true, canRestore: true), .arrange)
        XCTAssertEqual(recovery.advance(now: 2.5, ready: true, canRestore: true), .start)
    }

    func testDisappearingDisplayIsNotReconfiguredUntilItReturns() {
        var recovery = OutputStartupRecovery(now: 0)
        XCTAssertEqual(recovery.advance(now: 1, ready: false, canRestore: false), .wait)
        XCTAssertEqual(recovery.advance(now: 3, ready: false, canRestore: true), .restore)
        XCTAssertEqual(recovery.advance(now: 4, ready: true, canRestore: true), .arrange)
        XCTAssertEqual(recovery.advance(now: 4.5, ready: true, canRestore: true), .start)
    }

    func testArrangementCanInvalidateOutputAgain() {
        var recovery = OutputStartupRecovery(now: 0)
        XCTAssertEqual(recovery.advance(now: 1, ready: true, canRestore: true), .arrange)
        XCTAssertEqual(recovery.advance(now: 1.5, ready: false, canRestore: true), .restore)
        XCTAssertEqual(recovery.advance(now: 2.5, ready: true, canRestore: true), .start)
    }

    func testFailedRestoresDoNotLoopForever() {
        var recovery = OutputStartupRecovery(now: 0)
        XCTAssertEqual(recovery.advance(now: 1, ready: false, canRestore: true), .restore)
        XCTAssertEqual(recovery.advance(now: 2, ready: false, canRestore: true), .restore)
        XCTAssertEqual(recovery.advance(now: 3, ready: false, canRestore: true), .wait)
        XCTAssertEqual(recovery.advance(now: 8, ready: false, canRestore: true), .fail)
        XCTAssertEqual(recovery.attempts, 2)
    }

    func testActualUnplugTimesOutWithoutRestoreAttempts() {
        var recovery = OutputStartupRecovery(now: 100)
        XCTAssertEqual(recovery.advance(now: 107.9, ready: false, canRestore: false), .wait)
        XCTAssertEqual(recovery.advance(now: 108, ready: false, canRestore: false), .fail)
        XCTAssertEqual(recovery.attempts, 0)
    }
}
