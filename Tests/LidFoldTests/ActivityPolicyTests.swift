import XCTest
@testable import LidFoldCore

final class ActivityPolicyTests: XCTestCase {
    func testSleepThenWakeRestoresPreviouslyEnabledEffect() {
        var policy = ActivityPolicy()
        policy.request(true)
        policy.suspend(.systemSleep, resumeAutomatically: true)
        XCTAssertTrue(policy.requested)
        XCTAssertFalse(policy.canRun)
        policy.resume(.systemSleep)
        XCTAssertTrue(policy.canRun)
    }

    func testManualPauseNeverRestartsOnWake() {
        var policy = ActivityPolicy()
        policy.request(true)
        policy.suspend(.displaySleep, resumeAutomatically: true)
        policy.request(false)
        policy.resume(.displaySleep)
        XCTAssertFalse(policy.canRun)
    }

    func testEveryOverlappingInterruptionMustClear() {
        var policy = ActivityPolicy()
        policy.request(true)
        policy.suspend(.systemSleep, resumeAutomatically: true)
        policy.suspend(.locked, resumeAutomatically: true)
        policy.suspend(.displaySleep, resumeAutomatically: true)
        policy.resume(.systemSleep)
        policy.resume(.displaySleep)
        XCTAssertFalse(policy.canRun)
        policy.resume(.locked)
        XCTAssertTrue(policy.canRun)
    }

    func testDisabledAutoResumeRequiresExplicitEnable() {
        var policy = ActivityPolicy()
        policy.request(true)
        policy.suspend(.systemSleep, resumeAutomatically: false)
        policy.resume(.systemSleep)
        XCTAssertFalse(policy.canRun)
        policy.request(true)
        XCTAssertTrue(policy.canRun)
    }

    func testWakeDoesNotEnableAnAppThatWasAlreadyPaused() {
        var policy = ActivityPolicy()
        policy.suspend(.locked, resumeAutomatically: true)
        policy.resume(.locked)
        XCTAssertFalse(policy.canRun)
    }

    func testRepeatedNotificationsAndLateDisplayRecoveryAreSafe() {
        var policy = ActivityPolicy()
        policy.request(true)
        policy.suspend(.displayChange, resumeAutomatically: true)
        policy.suspend(.displayChange, resumeAutomatically: true)
        policy.request(false)
        policy.resume(.displayChange)
        policy.resume(.displayChange)
        XCTAssertFalse(policy.canRun)
    }
}
