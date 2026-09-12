import XCTest
@testable import LidFoldCore
@testable import LidFoldKit

final class PreferencesTests: XCTestCase {
    private func withStore(_ body: (PreferencesStore, UserDefaults) throws -> Void) rethrows {
        let name = "LidFoldTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(PreferencesStore(defaults: defaults), defaults)
    }

    func testPreferencesSurviveNewStoreInstance() {
        withStore { store, defaults in
            var settings = AppPreferences()
            settings.clearAngle = 119
            settings.blur = 21
            settings.shadow = 0.2
            settings.enableOnLaunch = true
            settings.resumeAfterWake = false
            settings.showMenuBarAngle = false
            store.save(settings)
            XCTAssertEqual(PreferencesStore(defaults: defaults).load(), settings)
        }
    }

    func testMissingFieldsUseCompatibleDefaultsAndCorruptDataDoesNotCrash() throws {
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{\"clearAngle\":112}".utf8))
        XCTAssertEqual(decoded.clearAngle, 112)
        XCTAssertEqual(decoded.blur, 14)
        XCTAssertFalse(decoded.enableOnLaunch)
        withStore { store, defaults in
            defaults.set(Data("broken".utf8), forKey: "lidfold.preferences.v1")
            XCTAssertEqual(store.load(), AppPreferences())
        }
    }

    func testUnsafeNumbersAreSanitizedBeforeSaving() {
        withStore { store, _ in
            var preferences = AppPreferences()
            preferences.clearAngle = .nan
            preferences.blur = -100
            preferences.shadow = 999
            store.save(preferences)
            XCTAssertEqual(store.load().clearAngle, 105)
            XCTAssertEqual(store.load().blur, 0)
            XCTAssertEqual(store.load().shadow, 1)
        }
    }

    func testSettingsSaveAndApplyImmediately() {
        withStore { store, _ in
            let model = SettingsModel(store: store)
            var applied: AppPreferences?
            model.onPreferencesChanged = { applied = $0 }
            model.set(\.clearAngle, to: 120)
            XCTAssertEqual(store.load().clearAngle, 120)
            XCTAssertEqual(applied?.clearAngle, 120)
        }
    }

    func testResetOnlyResetsEffectParameters() {
        withStore { store, _ in
            let model = SettingsModel(store: store)
            model.set(\.enableOnLaunch, to: true)
            model.set(\.showMenuBarAngle, to: false)
            model.set(\.clearAngle, to: 125)
            model.set(\.shadow, to: 0)
            model.resetEffect()
            XCTAssertEqual(store.load().clearAngle, 105)
            XCTAssertEqual(store.load().shadow, 0.55)
            XCTAssertTrue(store.load().enableOnLaunch)
            XCTAssertFalse(store.load().showMenuBarAngle)
        }
    }
}
