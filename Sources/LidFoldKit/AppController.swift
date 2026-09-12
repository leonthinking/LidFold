import AppKit
import MetalKit
import Carbon
import LidFoldCore

public final class AppController: NSObject, NSApplicationDelegate {
    private let sensor = LidSensor()
    private let capture = DesktopCapture()
    private var renderer: MetalRenderer?
    private var overlay: OverlayWindow?
    private var window: NSWindow?
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var enabled = false
    private var generation = SessionToken()
    private var fold = FoldState()
    private var angle: Double?
    private var lastSensorTime = 0.0
    private var lastUITime = 0.0
    private var captureStartedAt = 0.0
    private var renderTimer: Timer?
    private var watchdog: Timer?
    private var lastRenderTime = 0.0
    private var previewUntil = 0.0
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var observers: [NSObjectProtocol] = []
    private let statusLabel = NSTextField(wrappingLabelWithString: "准备就绪。启用后，请缓慢合上屏幕观察效果。")
    private let angleLabel = NSTextField(labelWithString: "—°")
    private let enableButton = NSButton(title: "启用桌面效果", target: nil, action: nil)
    private let previewButton = NSButton(title: "预览 5 秒", target: nil, action: nil)
    private let thresholdLabel = NSTextField(labelWithString: "开始折叠：105°")

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        buildWindow()
        installHotKey()
        installObservers()
        watchdog = MainLoopTimer.repeating(every: 0.5) { [weak self] _ in
            guard let self, self.enabled else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if self.lastSensorTime > 0, now - self.lastSensorTime > 1 {
                self.pause(message: "角度数据超时，效果已暂停。")
            } else if self.captureStartedAt > 0, now - self.captureStartedAt > 8, self.renderer?.hasFrame != true {
                self.pause(message: "未收到桌面画面，请检查屏幕录制权限后重新启用。")
            }
        }
        showWindow()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "LidFold")
        let menu = NSMenu()
        let open = NSMenuItem(title: "LidFold 设置…", action: #selector(showWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        enabledItem = NSMenuItem(title: "启用桌面效果", action: #selector(toggle), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "紧急暂停：⌘⇧Esc", action: nil, keyEquivalent: "")
        menu.addItem(hint)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 LidFold", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func buildWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 550), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "LidFold · 开合之间"
        window.isReleasedWhenClosed = false
        window.center()
        let title = NSTextField(labelWithString: "让桌面，随屏幕折叠。")
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "MacBook 真实开合联动 · 本地原型")
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: 14)
        angleLabel.font = .monospacedDigitSystemFont(ofSize: 56, weight: .light)
        angleLabel.textColor = .controlAccentColor
        let angleHint = NSTextField(labelWithString: "当前屏幕角度")
        angleHint.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.maximumNumberOfLines = 3
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let slider = NSSlider(value: 105, minValue: 75, maxValue: 130, target: self, action: #selector(thresholdChanged(_:)))
        slider.isContinuous = true
        slider.setAccessibilityLabel("开始折叠的屏幕角度")
        enableButton.target = self
        enableButton.action = #selector(toggle)
        enableButton.bezelStyle = .rounded
        enableButton.keyEquivalent = "\r"
        previewButton.target = self
        previewButton.action = #selector(preview)
        previewButton.bezelStyle = .rounded
        previewButton.isEnabled = false
        let buttons = NSStackView(views: [enableButton, previewButton])
        buttons.spacing = 12
        let privacy = NSTextField(wrappingLabelWithString: "需要「屏幕与系统音频录制」权限；本应用仅处理画面，不采集音频，不保存或上传。\n⌘⇧Esc 随时暂停。仅作用于内置屏幕，不改变合盖睡眠。")
        privacy.font = .systemFont(ofSize: 11)
        privacy.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, subtitle, angleLabel, angleHint, statusLabel, thresholdLabel, slider, buttons, privacy])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(24, after: subtitle)
        stack.setCustomSpacing(20, after: statusLabel)
        stack.setCustomSpacing(20, after: buttons)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
                slider.widthAnchor.constraint(equalTo: stack.widthAnchor),
                statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
                privacy.widthAnchor.constraint(equalTo: stack.widthAnchor)
            ])
        }
        self.window = window
    }

    @objc private func thresholdChanged(_ sender: NSSlider) {
        fold.clearAngle = sender.doubleValue.rounded()
        thresholdLabel.stringValue = "开始折叠：\(Int(fold.clearAngle))°"
        if enabled { scheduleRendering() }
    }

    @objc private func showWindow() {
        if enabled { pause(message: "已暂停效果，方便调整设置。调整后可重新启用。") }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggle() {
        if enabled { pause(message: "已暂停。桌面恢复正常。") }
        else { enable() }
    }

    private func enable() {
        guard !enabled else { return }
        guard CGPreflightScreenCaptureAccess() else {
            statusLabel.stringValue = "请在系统设置中允许 LidFold 录制屏幕，再回到这里启用；系统可能要求重新打开应用。"
            if !CGRequestScreenCaptureAccess(), let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }), let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else {
            statusLabel.stringValue = "未找到内置屏幕。请打开 MacBook 屏幕后重试。"
            return
        }
        do {
            guard let device = MTLCreateSystemDefaultDevice() else { throw LidFoldError.message("此设备无法使用 Metal。") }
            let renderer = try MetalRenderer(validatingDevice: device)
            self.renderer = renderer
            overlay = OverlayWindow(screen: screen, renderer: renderer)
        } catch {
            statusLabel.stringValue = error.localizedDescription
            return
        }
        enabled = true
        lastSensorTime = ProcessInfo.processInfo.systemUptime
        captureStartedAt = lastSensorTime
        let token = generation.invalidate()
        updateControls()
        statusLabel.stringValue = "正在连接角度传感器与桌面…"
        sensor.start { [weak self] result in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            switch result {
            case .success(let angle):
                self.angle = angle
                self.lastSensorTime = ProcessInfo.processInfo.systemUptime
                if self.lastSensorTime - self.lastUITime > 0.25 {
                    self.angleLabel.stringValue = "\(Int(angle))°"
                    self.statusItem.button?.title = " \(Int(angle))°"
                    self.lastUITime = self.lastSensorTime
                }
                self.scheduleRendering()
            case .failure(let error): self.pause(message: error.localizedDescription)
            }
        }
        capture.onFrame = { [weak self] frame in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            self.renderer?.update(frame: frame)
            self.previewButton.isEnabled = true
            self.scheduleRendering()
        }
        capture.onFailure = { [weak self] error in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            self.pause(message: "桌面捕获中断：\(error.localizedDescription)")
        }
        Task { @MainActor [weak self] in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            do {
                try await self.capture.start(displayID: displayID)
                guard self.enabled, self.generation.accepts(token) else { return }
                self.statusLabel.stringValue = "已启用。缓慢合上屏幕，或点击「预览 5 秒」。"
            } catch {
                guard self.generation.accepts(token) else { return }
                self.pause(message: "无法捕获桌面：\(error.localizedDescription)")
            }
        }
    }

    @objc private func preview() {
        guard enabled, renderer?.hasFrame == true else { return }
        previewUntil = ProcessInfo.processInfo.systemUptime + 5
        window?.orderOut(nil)
        scheduleRendering()
    }

    private func scheduleRendering() {
        guard enabled, renderer?.hasFrame == true, let angle else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard fold.target(for: angle) > 0 || fold.progress > 0 || previewUntil > now else { return }
        guard renderTimer == nil else { return }
        lastRenderTime = now
        renderTimer = MainLoopTimer.repeating(every: 1.0 / 60) { [weak self] _ in self?.renderTick() }
    }

    private func renderTick() {
        guard enabled, let renderer, renderer.hasFrame, let angle, let overlay else { hideOverlay(); return }
        let now = ProcessInfo.processInfo.systemUptime
        var target = fold.target(for: angle)
        if previewUntil > now {
            let elapsed = 5 - (previewUntil - now)
            target = 0.72 * sin(.pi * min(1, max(0, elapsed / 5)))
        }
        let progress = fold.advance(to: target, deltaTime: now - lastRenderTime)
        lastRenderTime = now
        if progress < 0.001, target == 0 { hideOverlay(); return }
        renderer.progress = Float(progress)
        if !overlay.isVisible { overlay.orderFrontRegardless() }
        overlay.metalView.draw()
    }

    private func hideOverlay() {
        overlay?.orderOut(nil)
        renderTimer?.invalidate()
        renderTimer = nil
        fold.reset()
    }

    private func pause(message: String) {
        generation.invalidate()
        enabled = false
        captureStartedAt = 0
        previewUntil = 0
        hideOverlay()
        capture.stop()
        sensor.stop()
        renderer?.clear()
        overlay?.close()
        overlay = nil
        renderer = nil
        angle = nil
        angleLabel.stringValue = "—°"
        statusItem.button?.title = ""
        statusLabel.stringValue = message
        updateControls()
    }

    private func updateControls() {
        enableButton.title = enabled ? "暂停效果" : "启用桌面效果"
        enabledItem.title = enableButton.title
        enabledItem.state = enabled ? .on : .off
        if !enabled { previewButton.isEnabled = false }
    }

    private func installHotKey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue()
            app.pause(message: "已通过 ⌘⇧Esc 暂停。")
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        let id = EventHotKeyID(signature: 0x4C464C44, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_Escape), UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { statusLabel.stringValue = "快捷键注册失败；可通过菜单栏暂停效果。" }
    }

    private func installObservers() {
        // NSWorkspace session notifications describe user switching, not every screen lock.
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            self?.pause(message: "屏幕已锁定，效果已暂停。解锁后可重新启用。")
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.pause(message: "系统进入睡眠或锁定，效果已暂停。恢复后可重新启用。")
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.enabled else { return }
            self.pause(message: "显示器配置已变化，效果已暂停。请重新启用。")
        })
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    public func applicationWillTerminate(_ notification: Notification) {
        pause(message: "已退出")
        watchdog?.invalidate()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}
