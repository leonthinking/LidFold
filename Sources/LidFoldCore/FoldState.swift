import Foundation

public enum LidReport {
    /// Apple orientation sensor, input report 1: ID followed by a 9-bit degree value.
    public static func angle(from bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let angle = Int(bytes[1]) | (Int(bytes[2]) << 8)
        guard (0...360).contains(angle) else { return nil }
        return Double(angle)
    }
}

public struct FoldState {
    public var clearAngle: Double = 105
    public var closedAngle: Double = 15
    public private(set) var progress: Double = 0

    public init() {}

    public func target(for angle: Double) -> Double {
        guard angle.isFinite, clearAngle.isFinite, closedAngle.isFinite,
              clearAngle > closedAngle else { return 0 }
        let t = min(1, max(0, (clearAngle - angle) / (clearAngle - closedAngle)))
        return t * t * (3 - 2 * t)
    }

    @discardableResult
    public mutating func advance(to target: Double, deltaTime: Double) -> Double {
        guard target.isFinite, deltaTime.isFinite, deltaTime > 0 else { return progress }
        let bounded = min(1, max(0, target))
        progress += (bounded - progress) * (1 - exp(-min(deltaTime, 0.1) / 0.055))
        if abs(progress - bounded) < 0.0005 { progress = bounded }
        return progress
    }

    public mutating func reset() { progress = 0 }
}

/// Stopping or replacing a session invalidates all asynchronous work from the previous one.
public struct SessionToken {
    public private(set) var value: UInt64 = 0
    public init() {}
    @discardableResult public mutating func invalidate() -> UInt64 {
        value &+= 1
        return value
    }
    public func accepts(_ candidate: UInt64) -> Bool { candidate == value }
}
