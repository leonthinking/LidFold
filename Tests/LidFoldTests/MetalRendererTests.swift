import XCTest
import Metal
@testable import LidFoldKit

final class MetalRendererTests: XCTestCase {
    private func makeRenderer() throws -> MetalRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable in this environment")
        }
        return try MetalRenderer(validatingDevice: device)
    }

    func testOpenFramePreservesOrientationAndPixels() throws {
        let renderer = try makeRenderer()
        let width = 48, height = 32
        var input = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height { for x in 0..<width {
            let i = (y * width + x) * 4
            input[i] = UInt8(x * 4)
            input[i + 1] = UInt8(y * 6)
            input[i + 2] = 80
        } }
        let output = try renderer.renderForTesting(bgra: input, width: width, height: height, progress: 0)
        for i in input.indices { XCTAssertLessThanOrEqual(abs(Int(input[i]) - Int(output[i])), 1, "channel \(i)") }
    }

    func testFoldKeepsBottomHingeAndRecedesFromTop() throws {
        let renderer = try makeRenderer()
        let width = 64, height = 48
        let input = [UInt8](repeating: 255, count: width * height * 4)
        let output = try renderer.renderForTesting(bgra: input, width: width, height: height, progress: 0.55)
        XCTAssertEqual(output[width / 2 * 4], 0, "top center must recede into background")
        XCTAssertGreaterThan(output[((height - 1) * width + width / 2) * 4], 100, "bottom hinge must remain visible")
        XCTAssertEqual(output[((height / 2) * width) * 4], 0, "sides must narrow with perspective")
    }

    func testFullyClosedFrameIsOpaqueBlack() throws {
        let renderer = try makeRenderer()
        let input = [UInt8](repeating: 255, count: 32 * 24 * 4)
        let output = try renderer.renderForTesting(bgra: input, width: 32, height: 24, progress: 1)
        for i in stride(from: 0, to: output.count, by: 4) {
            XCTAssertEqual(Array(output[i..<i + 4]), [0, 0, 0, 255])
        }
    }
}
