import XCTest
import AppKit
@testable import LidFoldKit

final class MainLoopTimerTests: XCTestCase {
    func testSafetyTimerFiresDuringMenuTrackingMode() {
        XCTAssertTrue(Thread.isMainThread)
        let mode = RunLoop.Mode.eventTracking
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(rawValue: mode.rawValue as CFString))
        var fired = false
        let timer = MainLoopTimer.repeating(every: 0.005) { _ in fired = true }
        defer { timer.invalidate() }
        let deadline = Date(timeIntervalSinceNow: 0.2)
        while !fired, Date() < deadline { RunLoop.main.run(mode: mode, before: deadline) }
        XCTAssertTrue(fired, "Safety watchdog must run while menus track, just like rendering")
    }
}
