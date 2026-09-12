import Foundation

public struct AppPreferences: Codable, Equatable {
    public var clearAngle = 105.0
    public var blur = 14.0
    public var shadow = 0.55
    public var showMenuBarAngle = true
    public var enableOnLaunch = false
    public var resumeAfterWake = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case clearAngle, blur, shadow, showMenuBarAngle, enableOnLaunch, resumeAfterWake
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        clearAngle = try values.decodeIfPresent(Double.self, forKey: .clearAngle) ?? 105
        blur = try values.decodeIfPresent(Double.self, forKey: .blur) ?? 14
        shadow = try values.decodeIfPresent(Double.self, forKey: .shadow) ?? 0.55
        showMenuBarAngle = try values.decodeIfPresent(Bool.self, forKey: .showMenuBarAngle) ?? true
        enableOnLaunch = try values.decodeIfPresent(Bool.self, forKey: .enableOnLaunch) ?? false
        resumeAfterWake = try values.decodeIfPresent(Bool.self, forKey: .resumeAfterWake) ?? true
        self = validated()
    }

    public func validated() -> Self {
        var copy = self
        copy.clearAngle = clearAngle.isFinite ? min(130, max(75, clearAngle)) : 105
        copy.blur = blur.isFinite ? min(30, max(0, blur)) : 14
        copy.shadow = shadow.isFinite ? min(1, max(0, shadow)) : 0.55
        return copy
    }

    public mutating func resetEffect() {
        clearAngle = 105
        blur = 14
        shadow = 0.55
    }
}

public final class PreferencesStore {
    private let defaults: UserDefaults
    private let key = "lidfold.preferences.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> AppPreferences {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(AppPreferences.self, from: data) else { return AppPreferences() }
        return value
    }

    public func save(_ preferences: AppPreferences) {
        if let data = try? JSONEncoder().encode(preferences.validated()) { defaults.set(data, forKey: key) }
    }
}
