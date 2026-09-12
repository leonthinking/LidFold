import AppKit
import LidFoldKit
import Metal

if CommandLine.arguments.contains("--self-check") {
    guard Bundle.main.bundleIdentifier == "local.leon.LidFold",
          Bundle.main.url(forResource: "Fold", withExtension: "metal") != nil,
          let device = MTLCreateSystemDefaultDevice() else {
        fputs("FAIL: missing packaged resources or Metal device\n", stderr)
        exit(1)
    }
    do {
        _ = try MetalRenderer(validatingDevice: device)
        print("PASS: standalone app resources and Metal pipeline")
        exit(0)
    } catch {
        fputs("FAIL: \(error)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppController()
app.delegate = delegate
app.run()
