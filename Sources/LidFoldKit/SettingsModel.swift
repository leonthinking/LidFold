import AppKit
import Combine
import LidFoldCore

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, effect, about
    var id: String { rawValue }
    var title: String {
        switch self { case .general: return "通用"; case .effect: return "效果"; case .about: return "权限与关于" }
    }
    var symbol: String {
        switch self { case .general: return "gearshape"; case .effect: return "slider.horizontal.3"; case .about: return "info.circle" }
    }
}

final class SettingsModel: ObservableObject {
    @Published var pane: SettingsPane = .general
    @Published private(set) var preferences: AppPreferences
    @Published var effectsEnabled = false
    @Published var captureReady = false
    @Published var angle: Double?
    @Published var status = "已暂停"
    @Published var permissionGranted = false
    @Published var shortcutAvailable = true
    @Published var settingsVisible = false
    let store: PreferencesStore
    var onPreferencesChanged: ((AppPreferences) -> Void)?
    var onSetEnabled: ((Bool) -> Void)?
    var onPreview: (() -> Void)?
    var onPermissionHelp: (() -> Void)?
    var onRestart: (() -> Void)?

    init(store: PreferencesStore = PreferencesStore()) {
        self.store = store
        preferences = store.load()
    }

    func set<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>, to value: Value) {
        var updated = preferences
        updated[keyPath: keyPath] = value
        preferences = updated.validated()
        store.save(preferences)
        onPreferencesChanged?(preferences)
    }

    func resetEffect() {
        var updated = preferences
        updated.resetEffect()
        preferences = updated
        store.save(updated)
        onPreferencesChanged?(updated)
    }
}
