import AppKit
import ScreenCaptureKit
import CoreMedia
import LidFoldCore

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private var generation = SessionToken()
    var onFrame: ((CVPixelBuffer) -> Void)?
    var onFailure: ((Error) -> Void)?

    // All state and output delivery are confined to the main queue.
    @MainActor func start(displayID: CGDirectDisplayID) async throws {
        let token = generation.invalidate()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard generation.accepts(token) else { return }
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw LidFoldError.message("内置屏幕不可用。请打开 MacBook 屏幕后重试。")
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApps.isEmpty else {
            throw LidFoldError.message("无法排除效果窗口，已停止以避免画面递归。请重新启动应用。")
        }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        if #available(macOS 14.2, *) { filter.includeMenuBar = true }
        let configuration = SCStreamConfiguration()
        // Cap at 1920 px for this prototype; desktop frames never go to disk.
        let ratio = min(1, 1920 / Double(display.width))
        configuration.width = Int(Double(display.width) * ratio)
        configuration.height = Int(Double(display.height) * ratio)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.capturesAudio = false
        let candidate = SCStream(filter: filter, configuration: configuration, delegate: self)
        try candidate.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        stream = candidate
        do {
            try await candidate.startCapture()
        } catch {
            if stream === candidate { stream = nil }
            throw error
        }
        if !generation.accepts(token) {
            try? await candidate.stopCapture()
        }
    }

    func stop() {
        generation.invalidate()
        let previous = stream
        stream = nil
        if let previous { Task { try? await previous.stopCapture() } }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard self.stream === stream, type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: raw) else { return }
        switch status {
        case .complete:
            if let buffer = sampleBuffer.imageBuffer { onFrame?(buffer) }
        case .blank, .suspended, .stopped:
            onFailure?(LidFoldError.message("屏幕捕获已中断，效果已暂停。"))
        default: break // Idle frames are normal on a static desktop.
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.onFailure?(error)
        }
    }
}
