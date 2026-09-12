import AppKit
import MetalKit
import CoreVideo

public final class MetalRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var cache: CVMetalTextureCache?
    private var frame: CVPixelBuffer?
    public var progress: Float = 0
    public var blur: Float = 14
    public var shadow: Float = 0.55
    public var hasFrame: Bool { frame != nil }

    public override init() {
        fatalError("Use init(validatingDevice:) instead")
    }

    public init(validatingDevice device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue(),
              let url = Bundle.main.url(forResource: "Fold", withExtension: "metal")
                ?? Bundle.module.url(forResource: "Fold", withExtension: "metal") else {
            throw LidFoldError.message("Metal 初始化失败。")
        }
        commandQueue = queue
        let source = try String(contentsOf: url)
        let library = try device.makeLibrary(source: source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "foldVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "foldFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess else {
            throw LidFoldError.message("无法建立桌面纹理缓存。")
        }
    }

    public func update(frame: CVPixelBuffer) { self.frame = frame }
    public func clear() {
        frame = nil
        if let cache { CVMetalTextureCacheFlush(cache, 0) }
    }

    public func draw(in view: MTKView) {
        guard let frame, let cache,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = commandQueue.makeCommandBuffer() else { return }
        var wrapper: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(nil, cache, frame, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(frame), CVPixelBufferGetHeight(frame), 0, &wrapper)
        guard result == kCVReturnSuccess, let wrapper, let texture = CVMetalTextureGetTexture(wrapper) else { return }
        encode(texture: texture, pass: pass, command: command)
        // Keep the IOSurface and CV wrapper alive until the GPU has finished sampling them.
        command.addCompletedHandler { _ in _ = (frame, wrapper) }
        command.present(drawable)
        command.commit()
    }

    private func encode(texture: MTLTexture, pass: MTLRenderPassDescriptor, command: MTLCommandBuffer) {
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var uniforms = SIMD4<Float>(progress, blur, shadow, 0)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    /// Offscreen path exercises the same shader and pipeline as the live overlay.
    public func renderForTesting(bgra: [UInt8], width: Int, height: Int, progress: Float) throws -> [UInt8] {
        guard width > 0, height > 0, bgra.count == width * height * 4 else {
            throw LidFoldError.message("无效测试图像。")
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        desc.storageMode = .shared
        desc.usage = [.shaderRead, .renderTarget]
        guard let input = device.makeTexture(descriptor: desc), let output = device.makeTexture(descriptor: desc),
              let command = commandQueue.makeCommandBuffer() else { throw LidFoldError.message("Metal 纹理分配失败。") }
        bgra.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 4) }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let old = self.progress
        self.progress = progress
        encode(texture: input, pass: pass, command: command)
        self.progress = old
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        var bytes = [UInt8](repeating: 0, count: bgra.count)
        bytes.withUnsafeMutableBytes { output.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return bytes
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
