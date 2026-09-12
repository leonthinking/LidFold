import SwiftUI
import LidFoldCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var login: LoginItemController

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SettingsPane.allCases, selection: $model.pane) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 185, max: 220)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch model.pane {
                case .general: general
                case .effect: effect
                case .about: about
                }
            }
            .navigationTitle(model.pane.title)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 680, minHeight: 480)
    }

    private var general: some View {
        Form {
            Section("运行") {
                Toggle("启用桌面效果", isOn: Binding(get: { model.effectsEnabled }, set: { model.onSetEnabled?($0) }))
                LabeledContent("状态") {
                    Text(model.status).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                }
                LabeledContent("屏幕角度", value: model.angle.map { "\(Int($0))°" } ?? "—")
                Text("屏幕低于 \(Int(model.preferences.clearAngle))° 时开始折叠；设置窗口保持清晰，桌面继续随开合变化。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                Toggle("登录时启动", isOn: Binding(get: { login.registered }, set: { value in
                    Task { await login.setEnabled(value) }
                })).disabled(login.busy)
                if login.status == .requiresApproval {
                    LabeledContent("等待系统允许") {
                        Button("打开登录项设置…") { login.openSystemSettings() }
                    }
                }
                if let error = login.error { Text(error).foregroundStyle(.red).font(.callout) }
                Toggle("启动时启用效果", isOn: preference(\.enableOnLaunch))
                Toggle("唤醒或解锁后恢复效果", isOn: preference(\.resumeAfterWake))
            } header: {
                Text("启动与恢复")
            } footer: {
                Text("登录启动时安静驻留菜单栏。自动启用需要已有屏幕录制授权；唤醒时只恢复此前启用的效果，手动暂停后保持暂停。")
            }
            Section("菜单栏") {
                Toggle("显示屏幕角度", isOn: preference(\.showMenuBarAngle))
                LabeledContent("暂停快捷键", value: model.shortcutAvailable ? "⌘⇧Esc" : "不可用，请使用菜单栏暂停")
                LabeledContent("打开设置", value: "⌘,")
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    private var effect: some View {
        Form {
            Section {
                slider("开始折叠", value: preference(\.clearAngle), range: 75...130, display: "\(Int(model.preferences.clearAngle))°")
                slider("模糊强度", value: preference(\.blur), range: 0...30, display: "\(Int(model.preferences.blur / 30 * 100))%")
                slider("阴影强度", value: preference(\.shadow), range: 0...1, display: "\(Int(model.preferences.shadow * 100))%")
            } header: {
                Text("外观")
            } footer: {
                Text("屏幕低于设定角度时开始折叠。更改立即保存，桌面实时响应；设置窗口保持清晰可操作。")
            }
            Section {
                LabeledContent("桌面预览") {
                    Button("预览 5 秒") { model.onPreview?() }
                        .disabled(!model.captureReady)
                }
                if !model.captureReady { Text("在「通用」中启用效果后，即可预览。").foregroundStyle(.secondary) }
            } footer: {
                Text("预览会暂时收起设置窗口，用当前参数展示真实桌面；结束后返回设置。")
            }
            Section {
                Button("恢复效果默认值") { model.resetEffect() }
            } footer: {
                Text("只重置角度、模糊和阴影，保留启动与菜单栏设置。")
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        Form {
            Section("权限") {
                LabeledContent("屏幕录制", value: model.permissionGranted ? "已允许" : "尚未允许")
                Button("管理屏幕录制权限…") { model.onPermissionHelp?() }
            }
            Section("隐私") {
                Text("桌面画面仅在本机内存中处理，不保存、不上传，也不采集音频。")
                Text("仅作用于内置屏幕，不改变 MacBook 的合盖睡眠行为。")
            }
            Section("LidFold") {
                LabeledContent("版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版")
                LabeledContent("系统要求", value: "macOS 14 或更高版本")
                Text("需要带可读取开合角度传感器的 MacBook。").foregroundStyle(.secondary)
                Button("重新打开应用…") { model.onRestart?() }
            }
        }
        .formStyle(.grouped)
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
        Binding(get: { model.preferences[keyPath: keyPath] }, set: { model.set(keyPath, to: $0) })
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 20)
            HStack(spacing: 12) {
                Slider(value: value, in: range).accessibilityLabel(title).accessibilityValue(display)
                Text(display).monospacedDigit().foregroundStyle(.secondary).frame(width: 42, alignment: .trailing).accessibilityHidden(true)
            }.frame(minWidth: 170, maxWidth: 280)
        }
    }
}
