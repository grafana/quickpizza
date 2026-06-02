import Foundation
import Observation
import SwiftiePod

let debugSettingsRepositoryProvider = Provider<DebugSettingsRepository> { _ in
    DebugSettingsRepository(store: UserDefaults.standard)
}

// MARK: - KeyValueStore

protocol KeyValueStore {
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: KeyValueStore {}

// MARK: - DebugSettings

/// Snapshot of all values persisted by `DebugSettingsRepository`.
///
/// URL overrides are nullable — `nil` means "no override, use the build-time default".
/// Boolean toggles default to `false`.
struct DebugSettings: Equatable {
    var backendUrlOverride: String? = nil
    var otlpEndpointOverride: String? = nil
    var otlpInstanceIdOverride: String? = nil
    var otlpApiKeyOverride: String? = nil
    var errorOnRecommendations: Bool = false
    var errorOnIngredients: Bool = false
    var slowRecommendations: Bool = false
    var slowIngredients: Bool = false
    var useV2PizzaSchema: Bool = false
    var skipAuthDepInTools: Bool = false

    var hasActiveOverrides: Bool {
        backendUrlOverride != nil ||
            otlpEndpointOverride != nil ||
            otlpInstanceIdOverride != nil ||
            otlpApiKeyOverride != nil ||
            errorOnRecommendations ||
            errorOnIngredients ||
            slowRecommendations ||
            slowIngredients ||
            useV2PizzaSchema ||
            skipAuthDepInTools
    }

    /// Backend expects:
    ///  * `x-error-*` headers — value is the error message (any non-empty string)
    ///  * `x-delay-*` headers — value is a Go duration string (e.g. `3s`, `500ms`)
    ///
    /// Delay values are tuned so both toggles produce ~3s of user-visible
    /// slowness. `record-recommendation` is called once per `POST /api/pizza`,
    /// so 3s → ~3s. `get-ingredients` is called four times per request
    /// (oil, tomato, mozzarella, topping), so 750ms → ~3s total.
    var errorInjectionHeaders: [String: String] {
        var headers: [String: String] = [:]
        if errorOnRecommendations {
            headers["x-error-record-recommendation"] = "simulated recommendation service failure"
        }
        if errorOnIngredients {
            headers["x-error-get-ingredients"] = "simulated ingredient lookup failure"
        }
        if slowRecommendations {
            headers["x-delay-record-recommendation"] = "3s"
        }
        if slowIngredients {
            headers["x-delay-get-ingredients"] = "750ms"
        }
        return headers
    }
}

// MARK: - Repository

private enum DebugSettingsKey {
    static let backendUrl = "debug_backend_url"
    static let otlpEndpoint = "debug_otlp_endpoint"
    static let otlpInstanceId = "debug_otlp_instance_id"
    static let otlpApiKey = "debug_otlp_api_key"
    static let errorRecommendations = "debug_error_recommendations"
    static let errorIngredients = "debug_error_ingredients"
    static let slowRecommendations = "debug_slow_recommendations"
    static let slowIngredients = "debug_slow_ingredients"
    static let useV2PizzaSchema = "debug_use_v2_pizza_schema"
    static let skipAuthDepInTools = "debug_skip_auth_dep_in_tools"
}

/// Persists `DebugSettings` in a `KeyValueStore` and exposes a hot
/// snapshot (`current`). Marked `@Observable` so consumers can stream
/// changes via `Observations { repo.current }` (Swift 6.2).
@Observable
final class DebugSettingsRepository {
    @ObservationIgnored private let store: KeyValueStore

    private(set) var current: DebugSettings

    init(store: KeyValueStore) {
        self.store = store
        self.current = Self.load(from: store)
    }

    // MARK: Mutators (URL overrides)

    /// Persist all URL + OTLP credential overrides atomically. Empty / blank
    /// values clear the corresponding override.
    func saveConfigOverrides(
        backendUrl: String?,
        otlpEndpoint: String?,
        otlpInstanceId: String?,
        otlpApiKey: String?
    ) {
        setString(DebugSettingsKey.backendUrl, value: normalize(backendUrl))
        setString(DebugSettingsKey.otlpEndpoint, value: normalize(otlpEndpoint))
        setString(DebugSettingsKey.otlpInstanceId, value: normalize(otlpInstanceId))
        setString(DebugSettingsKey.otlpApiKey, value: normalize(otlpApiKey))
        publish()
    }

    func setBackendUrlOverride(_ value: String?) {
        setString(DebugSettingsKey.backendUrl, value: normalize(value))
        publish()
    }

    func setOtlpEndpointOverride(_ value: String?) {
        setString(DebugSettingsKey.otlpEndpoint, value: normalize(value))
        publish()
    }

    func setOtlpInstanceIdOverride(_ value: String?) {
        setString(DebugSettingsKey.otlpInstanceId, value: normalize(value))
        publish()
    }

    func setOtlpApiKeyOverride(_ value: String?) {
        setString(DebugSettingsKey.otlpApiKey, value: normalize(value))
        publish()
    }

    // MARK: Mutators (toggles)

    func setErrorOnRecommendations(_ value: Bool) {
        store.set(value, forKey: DebugSettingsKey.errorRecommendations)
        publish()
    }

    func setErrorOnIngredients(_ value: Bool) {
        store.set(value, forKey: DebugSettingsKey.errorIngredients)
        publish()
    }

    func setSlowRecommendations(_ value: Bool) {
        store.set(value, forKey: DebugSettingsKey.slowRecommendations)
        publish()
    }

    func setSlowIngredients(_ value: Bool) {
        store.set(value, forKey: DebugSettingsKey.slowIngredients)
        publish()
    }

    func setUseV2PizzaSchema(_ value: Bool) {
        store.set(value, forKey: DebugSettingsKey.useV2PizzaSchema)
        publish()
    }

    func setSkipAuthDepInTools(_ value: Bool) {
        store.set(value, forKey: DebugSettingsKey.skipAuthDepInTools)
        publish()
    }

    func resetAll() {
        for key in [
            DebugSettingsKey.backendUrl,
            DebugSettingsKey.otlpEndpoint,
            DebugSettingsKey.otlpInstanceId,
            DebugSettingsKey.otlpApiKey,
            DebugSettingsKey.errorRecommendations,
            DebugSettingsKey.errorIngredients,
            DebugSettingsKey.slowRecommendations,
            DebugSettingsKey.slowIngredients,
            DebugSettingsKey.useV2PizzaSchema,
            DebugSettingsKey.skipAuthDepInTools,
        ] {
            store.removeObject(forKey: key)
        }
        publish()
    }

    // MARK: Private

    private func setString(_ key: String, value: String?) {
        if let value {
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    private func normalize(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func publish() {
        current = Self.load(from: store)
    }

    private static func load(from store: KeyValueStore) -> DebugSettings {
        DebugSettings(
            backendUrlOverride: store.string(forKey: DebugSettingsKey.backendUrl),
            otlpEndpointOverride: store.string(forKey: DebugSettingsKey.otlpEndpoint),
            otlpInstanceIdOverride: store.string(forKey: DebugSettingsKey.otlpInstanceId),
            otlpApiKeyOverride: store.string(forKey: DebugSettingsKey.otlpApiKey),
            errorOnRecommendations: store.bool(forKey: DebugSettingsKey.errorRecommendations),
            errorOnIngredients: store.bool(forKey: DebugSettingsKey.errorIngredients),
            slowRecommendations: store.bool(forKey: DebugSettingsKey.slowRecommendations),
            slowIngredients: store.bool(forKey: DebugSettingsKey.slowIngredients),
            useV2PizzaSchema: store.bool(forKey: DebugSettingsKey.useV2PizzaSchema),
            skipAuthDepInTools: store.bool(forKey: DebugSettingsKey.skipAuthDepInTools)
        )
    }
}
