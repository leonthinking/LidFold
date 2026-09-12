/// The system prompt is attempted once per process. A grant returned by that
/// prompt is usable immediately; returning from Settings can be checked again.
public struct ScreenPermissionGate {
    public private(set) var hasRequested = false
    public init() {}

    public mutating func authorize(preflight: () -> Bool, request: () -> Bool) -> Bool {
        if preflight() { return true }
        guard !hasRequested else { return false }
        hasRequested = true
        if request() { return true }
        return preflight()
    }
}
