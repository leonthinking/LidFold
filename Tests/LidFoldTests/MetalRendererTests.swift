import XCTest
import Metal
@testable import LidFoldKit

final class MetalRendererTests: XCTestCase {
    private func makeRenderer() throws -> MetalRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable in this environment")
        }
        // A hosted VM can expose a Metal device without usable render/readback.
        // Probe a shader-free clear before testing LidFold; never skip on a
        // LidFold pixel mismatch or apply this exemption to a physical runner.
        let usable = canReadBackClear(on: device)
        let environment = ProcessInfo.processInfo.environment
        if !usable, environment["GITHUB_ACTIONS"] == "true",
           environment["RUNNER_ENVIRONMENT"] == "github-hosted" {
            throw XCTSkip("Hosted Metal device \(device.name) cannot read back a shader-free clear; physical GPU verification required")
        }
        guard usable else {
            XCTFail("Metal device \(device.name) failed the shader-free clear/readback probe")
            throw NSError(domain: "LidFoldTests.Metal", code: 1)
        }
        return try MetalRenderer(validatingDevice: device)
    }

    private func canReadBackClear(on device: MTLDevice) -> Bool {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .renderTarget
        guard let texture = device.makeTexture(descriptor: descriptor),
              let command = device.makeCommandQueue()?.makeCommandBuffer() else { return false }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed, command.error == nil else { return false }
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
        }
        return pixel == [0, 0, 255, 255]
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
        if let i = input.indices.first(where: { abs(Int(input[$0]) - Int(output[$0])) > 1 }) {
            XCTFail("First pixel mismatch at channel \(i): expected \(input[i]), got \(output[i])")
        }
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
            if Array(output[i..<i + 4]) != [0, 0, 0, 255] {
                XCTFail("Expected opaque black at pixel \(i / 4), got \(Array(output[i..<i + 4]))")
                break
            }
        }
    }
}
