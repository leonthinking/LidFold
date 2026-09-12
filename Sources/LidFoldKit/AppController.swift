import AppKit
import SwiftUI
import MetalKit
import Carbon
import LidFoldCore

public final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let sensor = LidSensor()
    private let capture = DesktopCapture()
    private let settings = SettingsModel()
    private let login = LoginItemController()
    private var activity = ActivityPolicy()
    private var renderer: MetalRenderer?
    private var overlay: OverlayWindow?
    private var window: NSWindow?
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var enabled = false
    private var permissionGate = ScreenPermissionGate()
    private var waitingForPermission = false
    private var generation = SessionToken()
    private var recovery = SessionToken()
    private var displayChange = SessionToken()
    private var fold = FoldState()
    private var angle: Double?
    private var lastSensorTime = 0.0
    private var lastUITime = 0.0
    private var captureStartedAt = 0.0
    private var renderTimer: Timer?
    private var watchdog: Timer?
    private var lastRenderTime = 0.0
    private var previewUntil = 0.0
    private let previewDeadline = PreviewDeadline()
    private var returnToSettingsAfterPreview = false
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var observers: [NSObjectProtocol] = []

    public override init() { super.init() }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings.onSetEnabled = { [weak self] in self?.setUserEnabled($0) }
        settings.onPreferencesChanged = { [weak self] in self?.applyPreferences($0) }
        settings.onPreview = { [weak self] in self?.preview() }
        settings.onPermissionHelp = { [weak self] in self?.showPermissionHelp() }
        settings.onRestart = { [weak self] in self?.restartApplication() }
        buildMenu()
        buildWindow()
        applyPreferences(settings.preferences)
        installHotKey()
        installObservers()
        refreshSystemState()
        watchdog = MainLoopTimer.repeating(every: 0.5) { [weak self] _ in
            guard let self, self.enabled else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if now - self.lastSensorTime > 1 {
                self.fail("角度数据超时，效果已暂停。")
            } else if now - self.captureStartedAt > 8, !self.settings.captureReady {
                self.fail("未收到桌面画面，请检查屏幕录制权限后重新启用。")
            }
        }
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch { showWindow() }
        if settings.preferences.enableOnLaunch {
            activity.request(true)
            reconcile(requestPermission: false)
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "LidFold")
        let menu = NSMenu()
        let open = NSMenuItem(title: "设置…", action: #selector(showWindow), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)
        enabledItem = NSMenuItem(title: "启用桌面效果", action: #selector(toggle), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "紧急暂停：⌘⇧Esc", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 LidFold", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu

        let main = NSMenu()
        let application = NSMenuItem()
        let applicationMenu = NSMenu(title: "LidFold")
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(showWindow), keyEquivalent: ",")
        settingsItem.target = self
        applicationMenu.addItem(settingsItem)
        applicationMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 LidFold", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        applicationMenu.addItem(quitItem)
        application.submenu = applicationMenu
        main.addItem(application)
        let windowItem = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    private func buildWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "LidFold 设置"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = NSSize(width: 680, height: 480)
        window.contentViewController = NSHostingController(rootView: SettingsView(model: settings, login: login))
        window.setFrameAutosaveName("LidFold.Settings")
        if !window.setFrameUsingName("LidFold.Settings") { window.center() }
        self.window = window
    }

    private func applyPreferences(_ preferences: AppPreferences) {
        fold.clearAngle = preferences.clearAngle
        renderer?.blur = Float(preferences.blur)
        renderer?.shadow = Float(preferences.shadow)
        updateMenuAngle()
        if !preferences.resumeAfterWake && !activity.interruptions.isEmpty {
            activity.request(false)
            settings.status = "已暂停"
            updateControls()
        }
        scheduleRendering()
    }

    @objc private func showWindow() {
        settings.settingsVisible = true
        previewDeadline.cancel()
        previewUntil = 0
        returnToSettingsAfterPreview = false
        hideOverlay()
        refreshSystemState()
        if enabled { settings.status = "已启用，设置期间隐藏效果" }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        settings.settingsVisible = false
        if enabled { settings.status = "已启用"; scheduleRendering() }
    }

    public func windowDidMiniaturize(_ notification: Notification) {
        settings.settingsVisible = false
        if enabled { settings.status = "已启用"; scheduleRendering() }
    }

    public func windowDidDeminiaturize(_ notification: Notification) {
        settings.settingsVisible = true
        previewDeadline.cancel()
        previewUntil = 0
        returnToSettingsAfterPreview = false
        hideOverlay()
        if enabled { settings.status = "已启用，设置期间隐藏效果" }
    }

    @objc private func toggle() { setUserEnabled(!activity.requested) }

    private func setUserEnabled(_ value: Bool) {
        waitingForPermission = false
        activity.request(value)
        if value { reconcile(requestPermission: true) }
        else { stopSession(message: "已暂停") }
    }

    private func reconcile(requestPermission: Bool) {
        updateControls()
        guard activity.canRun else {
            if activity.requested { settings.status = "等待屏幕唤醒或解锁" }
            return
        }
        startSession(requestPermission: requestPermission)
    }

    private func startSession(requestPermission: Bool) {
        guard !enabled else { return }
        let allowed = requestPermission
            ? permissionGate.authorize(preflight: CGPreflightScreenCaptureAccess, request: CGRequestScreenCaptureAccess)
            : CGPreflightScreenCaptureAccess()
        settings.permissionGranted = allowed
        guard allowed else {
            activity.request(false)
            waitingForPermission = requestPermission
            settings.status = "需要屏幕录制授权，请前往「权限与关于」"
            updateControls()
            return
        }
        waitingForPermission = false
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }), let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else {
            fail("未找到内置屏幕，请打开 MacBook 屏幕后重试。")
            return
        }
        do {
            guard let device = MTLCreateSystemDefaultDevice() else { throw LidFoldError.message("此设备无法使用 Metal。") }
            let renderer = try MetalRenderer(validatingDevice: device)
            renderer.blur = Float(settings.preferences.blur)
            renderer.shadow = Float(settings.preferences.shadow)
            self.renderer = renderer
            overlay = OverlayWindow(screen: screen, renderer: renderer)
        } catch { fail(error.localizedDescription); return }
        enabled = true
        lastSensorTime = ProcessInfo.processInfo.systemUptime
        captureStartedAt = lastSensorTime
        let token = generation.invalidate()
        settings.status = "正在连接传感器与桌面…"
        updateControls()
        sensor.start { [weak self] result in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            switch result {
            case .success(let angle):
                self.angle = angle
                self.lastSensorTime = ProcessInfo.processInfo.systemUptime
                if self.lastSensorTime - self.lastUITime > 0.25 {
                    self.settings.angle = angle
                    self.updateMenuAngle()
                    self.lastUITime = self.lastSensorTime
                }
                self.scheduleRendering()
            case .failure(let error): self.fail(error.localizedDescription)
            }
        }
        capture.onFrame = { [weak self] frame in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            self.renderer?.update(frame: frame)
            if !self.settings.captureReady {
                self.settings.captureReady = true
                self.settings.status = self.settings.settingsVisible ? "已启用，设置期间隐藏效果" : "已启用"
            }
            self.scheduleRendering()
        }
        capture.onFailure = { [weak self] error in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            self.fail("桌面捕获中断：\(error.localizedDescription)")
        }
        capture.onUnavailable = { [weak self] in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            if self.settings.captureReady { self.captureStartedAt = ProcessInfo.processInfo.systemUptime }
            self.settings.captureReady = false
            self.renderer?.clear()
            self.hideOverlay()
            self.settings.status = "等待桌面画面恢复"
        }
        Task { @MainActor [weak self] in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            do { try await self.capture.start(displayID: displayID) }
            catch {
                guard self.generation.accepts(token) else { return }
                self.fail("无法捕获桌面：\(error.localizedDescription)")
            }
        }
    }

    private func preview() {
        guard enabled, settings.captureReady else { return }
        returnToSettingsAfterPreview = settings.settingsVisible
        settings.settingsVisible = false
        previewUntil = ProcessInfo.processInfo.systemUptime + 5
        let token = generation.value
        previewDeadline.schedule(after: 5) { [weak self] in
            guard let self, self.enabled, self.generation.accepts(token) else { return }
            self.previewUntil = 0
            if self.returnToSettingsAfterPreview { self.showWindow() }
        }
        window?.orderOut(nil)
        scheduleRendering()
    }

    private func scheduleRendering() {
        guard enabled, renderer?.hasFrame == true, let angle, !settings.settingsVisible else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard fold.target(for: angle) > 0 || fold.progress > 0 || previewUntil > now else { return }
        guard renderTimer == nil else { return }
        lastRenderTime = now
        renderTimer = MainLoopTimer.repeating(every: 1.0 / 60) { [weak self] _ in self?.renderTick() }
    }

    private func renderTick() {
        guard enabled, let renderer, renderer.hasFrame, let angle, let overlay, !settings.settingsVisible else {
            hideOverlay(); return
        }
        let now = ProcessInfo.processInfo.systemUptime
        if previewUntil > 0 && now >= previewUntil {
            previewUntil = 0
            if returnToSettingsAfterPreview { showWindow(); return }
        }
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

    private func fail(_ message: String) {
        activity.request(false)
        waitingForPermission = false
        stopSession(message: message)
    }

    private func stopSession(message: String) {
        generation.invalidate()
        enabled = false
        captureStartedAt = 0
        previewDeadline.cancel()
        previewUntil = 0
        returnToSettingsAfterPreview = false
        hideOverlay()
        capture.stop()
        sensor.stop()
        renderer?.clear()
        overlay?.close()
        overlay = nil
        renderer = nil
        angle = nil
        settings.angle = nil
        settings.captureReady = false
        settings.status = message
        updateMenuAngle()
        updateControls()
    }

    private func updateMenuAngle() {
        statusItem?.button?.title = settings.preferences.showMenuBarAngle ? angle.map { " \(Int($0))°" } ?? "" : ""
    }

    private func updateControls() {
        settings.effectsEnabled = activity.requested
        enabledItem.title = activity.requested ? "暂停效果" : "启用桌面效果"
        enabledItem.state = activity.requested ? .on : .off
    }

    private func installHotKey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue()
            app.setUserEnabled(false)
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        let id = EventHotKeyID(signature: 0x4C464C44, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_Escape), UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &hotKey)
        settings.shortcutAvailable = result == noErr
    }

    private func refreshSystemState() {
        login.refresh()
        settings.permissionGranted = CGPreflightScreenCaptureAccess()
    }

    private func suspend(_ reason: ActivityPolicy.Interruption) {
        recovery.invalidate()
        waitingForPermission = false
        activity.suspend(reason, resumeAutomatically: settings.preferences.resumeAfterWake)
        stopSession(message: activity.requested ? "等待屏幕唤醒或解锁" : "已暂停")
    }

    private func resume(_ reason: ActivityPolicy.Interruption) {
        activity.resume(reason)
        let token = recovery.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.recovery.accepts(token) else { return }
            self.reconcile(requestPermission: false)
        }
    }

    private func installObservers() {
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.refreshSystemState()
            if self.waitingForPermission && self.settings.permissionGranted { self.setUserEnabled(true) }
        })
        let distributed = DistributedNotificationCenter.default()
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            observers.append(distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                if locked { self?.suspend(.locked) } else { self?.resume(.locked) }
            })
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, Notification.Name, ActivityPolicy.Interruption)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .displaySleep),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .inactiveSession)
        ]
        for (stop, start, reason) in pairs {
            observers.append(workspace.addObserver(forName: stop, object: nil, queue: .main) { [weak self] _ in self?.suspend(reason) })
            observers.append(workspace.addObserver(forName: start, object: nil, queue: .main) { [weak self] _ in self?.resume(reason) })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.suspend(.displayChange)
            let token = self.displayChange.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.displayChange.accepts(token) else { return }
                self.resume(.displayChange)
            }
        })
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    private func showPermissionHelp() {
        settings.settingsVisible = true
        hideOverlay()
        let alert = NSAlert()
        alert.messageText = "让屏幕录制授权生效"
        alert.informativeText = "在系统设置中允许 LidFold 录制屏幕。若开关已经开启，请重新打开应用。\n\n若曾使用旧的临时签名版本，请先从授权列表移除 LidFold，再添加当前应用。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "重新打开应用")
        alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
        case .alertSecondButtonReturn: restartApplication()
        default: break
        }
    }

    private func restartApplication() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        RelaunchHandoff.start(
            release: { self.releaseHotKey() },
            launch: { completion in
                NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
                    DispatchQueue.main.async { completion(error) }
                }
            },
            restore: { self.installHotKey() },
            terminate: { NSApp.terminate(nil) },
            onError: { self.settings.status = "重新打开失败：\($0.localizedDescription)" }
        )
    }

    private func releaseHotKey() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
        hotKey = nil
        hotKeyHandler = nil
    }

    public func applicationWillTerminate(_ notification: Notification) {
        activity.request(false)
        stopSession(message: "已退出")
        watchdog?.invalidate()
        releaseHotKey()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}
