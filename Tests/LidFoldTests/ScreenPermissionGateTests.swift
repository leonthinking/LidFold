import XCTest
@testable import LidFoldCore

final class ScreenPermissionGateTests: XCTestCase {
    func testExistingGrantDoesNotPrompt() {
        var gate = ScreenPermissionGate()
        XCTAssertTrue(gate.authorize(preflight: { true }, request: { XCTFail("Already authorized"); return false }))
    }

    func testGrantFromPromptContinuesSameEnableAttempt() {
        var gate = ScreenPermissionGate()
        XCTAssertTrue(gate.authorize(preflight: { false }, request: { true }))
    }

    func testRepeatedEnableDoesNotRepeatDeniedPrompt() {
        var gate = ScreenPermissionGate()
        var requests = 0
        for _ in 0..<3 {
            XCTAssertFalse(gate.authorize(preflight: { false }, request: { requests += 1; return false }))
        }
        XCTAssertEqual(requests, 1)
    }

    func testReturningFromSettingsCanUseNewGrant() {
        var gate = ScreenPermissionGate()
        XCTAssertFalse(gate.authorize(preflight: { false }, request: { false }))
        XCTAssertTrue(gate.authorize(preflight: { true }, request: { XCTFail("Must not prompt again"); return false }))
    }

    func testRefreshAfterPromptCanObserveUpdatedAuthorization() {
        var gate = ScreenPermissionGate()
        var checks = 0
        XCTAssertTrue(gate.authorize(preflight: { checks += 1; return checks > 1 }, request: { false }))
    }
}
