import XCTest
@testable import LidFoldCore

final class RelaunchHandoffTests: XCTestCase {
    func testHotKeyReleasedBeforeSuccessorStartsAndExitWaitsForLaunch() {
        var events: [String] = []
        var complete: ((Error?) -> Void)?
        RelaunchHandoff.start(
            release: { events.append("release") },
            launch: { callback in events.append("launch"); complete = callback },
            restore: { events.append("restore") },
            terminate: { events.append("exit") },
            onError: { _ in XCTFail("Successful launch") }
        )
        XCTAssertEqual(events, ["release", "launch"])
        complete?(nil)
        XCTAssertEqual(events, ["release", "launch", "exit"])
    }

    func testFailedLaunchRestoresShortcutWithoutTerminating() {
        struct Failure: Error {}
        var events: [String] = []
        RelaunchHandoff.start(
            release: { events.append("release") },
            launch: { $0(Failure()) },
            restore: { events.append("restore") },
            terminate: { XCTFail("Must keep the current app running") },
            onError: { _ in events.append("error") }
        )
        XCTAssertEqual(events, ["release", "restore", "error"])
    }
}
