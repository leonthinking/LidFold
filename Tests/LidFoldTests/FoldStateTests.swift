import XCTest
@testable import LidFoldCore

final class FoldStateTests: XCTestCase {
    func testSensorReportAndMalformedInput() {
        XCTAssertEqual(LidReport.angle(from: [1, 122, 0]), 122)
        XCTAssertEqual(LidReport.angle(from: [1, 104, 1]), 360)
        XCTAssertEqual(LidReport.angle(from: [1, 0, 0]), 0)
        XCTAssertNil(LidReport.angle(from: []))
        XCTAssertNil(LidReport.angle(from: [1, 12]))
        XCTAssertNil(LidReport.angle(from: [2, 122, 0]))
        XCTAssertNil(LidReport.angle(from: [1, 105, 1]))
        XCTAssertNil(LidReport.angle(from: [1, 255, 255]))
    }

    func testOpenClosedAndMonotonicFold() {
        let state = FoldState()
        XCTAssertEqual(state.target(for: 122), 0)
        XCTAssertEqual(state.target(for: 105), 0)
        XCTAssertEqual(state.target(for: 15), 1)
        XCTAssertEqual(state.target(for: 0), 1)
        XCTAssertEqual(state.target(for: 60), 0.5)
        var previous = 1.0
        for angle in 0...180 {
            let next = state.target(for: Double(angle))
            XCTAssertLessThanOrEqual(next, previous)
            XCTAssertTrue((0...1).contains(next))
            previous = next
        }
    }

    func testInvalidAnglesNeverCoverDesktop() {
        var state = FoldState()
        XCTAssertEqual(state.target(for: .nan), 0)
        XCTAssertEqual(state.target(for: .infinity), 0)
        state.clearAngle = state.closedAngle
        XCTAssertEqual(state.target(for: 0), 0)
    }

    func testSmoothingReturnsExactlyToNormalWithoutOvershoot() {
        var state = FoldState()
        for _ in 0..<100 {
            XCTAssertTrue((0...1).contains(state.advance(to: 1, deltaTime: 1.0 / 60)))
        }
        XCTAssertEqual(state.progress, 1)
        for _ in 0..<100 { state.advance(to: 0, deltaTime: 1.0 / 60) }
        XCTAssertEqual(state.progress, 0)
        state.advance(to: .nan, deltaTime: 1)
        state.advance(to: 1, deltaTime: .nan)
        XCTAssertEqual(state.progress, 0)
    }

    func testOldAsyncWorkCannotRestartStoppedSession() {
        var session = SessionToken()
        let original = session.invalidate()
        XCTAssertTrue(session.accepts(original))
        let restarted = session.invalidate()
        XCTAssertFalse(session.accepts(original))
        XCTAssertTrue(session.accepts(restarted))
    }
}
