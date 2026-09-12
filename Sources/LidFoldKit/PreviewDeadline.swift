import Foundation

/// The settings return deadline must not depend on capture frames or GPU draws.
final class PreviewDeadline {
    private var timer: Timer?
    func schedule(after interval: TimeInterval, completion: @escaping () -> Void) {
        cancel()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.timer = nil
            completion()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func cancel() { timer?.invalidate(); timer = nil }
    deinit { timer?.invalidate() }
}
