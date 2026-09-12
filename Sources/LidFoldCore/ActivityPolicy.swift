public struct ActivityPolicy {
    public enum Interruption: Hashable { case systemSleep, displaySleep, locked, inactiveSession, displayChange }
    public private(set) var requested = false
    public private(set) var interruptions: Set<Interruption> = []
    public var canRun: Bool { requested && interruptions.isEmpty }
    public init() {}
    public mutating func request(_ enabled: Bool) { requested = enabled }
    public mutating func suspend(_ reason: Interruption, resumeAutomatically: Bool) {
        interruptions.insert(reason)
        if !resumeAutomatically { requested = false }
    }
    public mutating func resume(_ reason: Interruption) { interruptions.remove(reason) }
}
