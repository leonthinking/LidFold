import XCTest
@testable import LidFoldKit

final class PreviewDeadlineTests: XCTestCase {
    func testSettingsReturnEvenWhenCaptureAndRenderingHaveStopped() {
        let deadline = PreviewDeadline()
        let returned = expectation(description: "Return without any capture or render callback")
        deadline.schedule(after: 0.01) { returned.fulfill() }
        wait(for: [returned], timeout: 1)
    }

    func testSleepOrManualStopCancelsPendingReturn() {
        let deadline = PreviewDeadline()
        let returned = expectation(description: "Must not reopen during sleep")
        returned.isInverted = true
        deadline.schedule(after: 0.01) { returned.fulfill() }
        deadline.cancel()
        wait(for: [returned], timeout: 0.05)
    }

    func testNewPreviewReplacesTheOldReturnDeadline() {
        let deadline = PreviewDeadline()
        let returned = expectation(description: "Latest preview returns")
        deadline.schedule(after: 0.01) { XCTFail("Cancelled preview must not return") }
        deadline.schedule(after: 0.02) { returned.fulfill() }
        wait(for: [returned], timeout: 1)
    }
}
