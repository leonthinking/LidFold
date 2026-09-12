import Foundation
import IOKit.hid
import LidFoldCore

public final class LidSensor {
    private let queue = DispatchQueue(label: "local.lidfold.sensor", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var failures = 0

    public init() {}

    public func start(onValue: @escaping (Result<Double, Error>) -> Void) {
        queue.async { [self] in
            close()
            let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
            self.manager = manager
            IOHIDManagerSetDeviceMatching(manager, [
                kIOHIDVendorIDKey: 0x05ac,
                kIOHIDDeviceUsagePageKey: 0x20,
                kIOHIDDeviceUsageKey: 0x8a
            ] as CFDictionary)
            let result = IOHIDManagerOpen(manager, 0)
            guard result == kIOReturnSuccess else {
                deliver(.failure(LidFoldError.message("无法打开角度传感器（\(result)）。请从 Finder 启动应用。")), to: onValue)
                close()
                return
            }
            let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
            guard let device = devices.first, IOHIDDeviceOpen(device, 0) == kIOReturnSuccess else {
                deliver(.failure(LidFoldError.message("未找到可读取的屏幕角度传感器。")), to: onValue)
                close()
                return
            }
            self.device = device
            failures = 0
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(3))
            timer.setEventHandler { [weak self] in self?.read(onValue) }
            self.timer = timer
            timer.resume()
        }
    }

    public func stop() { queue.async { [self] in close() } }

    private func read(_ callback: @escaping (Result<Double, Error>) -> Void) {
        guard let device else { return }
        var bytes = [UInt8](repeating: 0, count: 8)
        var count = bytes.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeInput, 1, &bytes, &count)
        if result == kIOReturnSuccess, let angle = LidReport.angle(from: Array(bytes.prefix(count))) {
            failures = 0
            deliver(.success(angle), to: callback)
        } else {
            failures += 1
            if failures >= 6 {
                deliver(.failure(LidFoldError.message("角度传感器暂时不可用，效果已关闭。请重新启用。")), to: callback)
                close()
            }
        }
    }

    private func deliver(_ result: Result<Double, Error>, to callback: @escaping (Result<Double, Error>) -> Void) {
        DispatchQueue.main.async { callback(result) }
    }

    private func close() {
        timer?.cancel()
        timer = nil
        if let device { IOHIDDeviceClose(device, 0) }
        device = nil
        if let manager { IOHIDManagerClose(manager, 0) }
        manager = nil
    }
}

public enum LidFoldError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}
