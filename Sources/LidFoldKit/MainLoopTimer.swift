import Foundation

enum MainLoopTimer {
    /// Rendering and its safety checks must continue together during menu tracking.
    static func repeating(every interval: TimeInterval, _ callback: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true, block: callback)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
