import XCTest
@testable import LidFoldCore

final class EffectPresentationPolicyTests: XCTestCase {
    func testRealLidMovementStillRendersWhileSettingsAreOpen() {
        let policy = EffectPresentationPolicy(enabled: true, hasFrame: true, hasAngle: true, settingsVisible: true)
        let fold = FoldState()
        XCTAssertGreaterThan(fold.target(for: 70), 0)
        XCTAssertTrue(policy.canRender)
        XCTAssertTrue(policy.keepSettingsAboveEffect)
    }

    func testClosingOrMinimizingSettingsKeepsRenderingWithoutRaisingSettings() {
        let policy = EffectPresentationPolicy(enabled: true, hasFrame: true, hasAngle: true, settingsVisible: false)
        XCTAssertTrue(policy.canRender)
        XCTAssertFalse(policy.keepSettingsAboveEffect)
    }

    func testPauseOrMissingInputDisablesPresentationEvenWithSettingsOpen() {
        for (enabled, frame, angle) in [(false, true, true), (true, false, true), (true, true, false)] {
            let policy = EffectPresentationPolicy(enabled: enabled, hasFrame: frame, hasAngle: angle, settingsVisible: true)
            XCTAssertFalse(policy.canRender)
            XCTAssertFalse(policy.keepSettingsAboveEffect)
        }
    }
}
