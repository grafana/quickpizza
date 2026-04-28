import Foundation
import Observation
import SwiftUI
import SwiftiePod

let configViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    ConfigViewModel(
        debugSettings: pod.resolve(debugSettingsRepositoryProvider),
        runtimeConfig: pod.resolve(runtimeConfigHolderProvider),
        configService: pod.resolve(configServiceProvider)
    )
}

// MARK: - UI State

struct ConfigUiState: Equatable {
    var backendInUse: String
    var otlpInUse: String
    var otlpInstanceIdInUse: String
    var otlpApiKeyInUse: String
    var defaultBackend: String
    var defaultOtlp: String
    var defaultOtlpInstanceId: String
    var defaultOtlpApiKey: String
    var savedBackendOverride: String?
    var savedOtlpOverride: String?
    var savedOtlpInstanceIdOverride: String?
    var savedOtlpApiKeyOverride: String?
    var saving: Bool = false
    var statusMessage: String? = nil
    var restartBanner: RestartBannerState = .hidden
}

// MARK: - ViewModel

@Observable
class ConfigViewModel {
    private let debugSettings: DebugSettingsRepository
    private let runtimeConfig: RuntimeConfigHolder
    private let configService: ConfigService

    var state: ConfigUiState

    init(
        debugSettings: DebugSettingsRepository,
        runtimeConfig: RuntimeConfigHolder,
        configService: ConfigService
    ) {
        self.debugSettings = debugSettings
        self.runtimeConfig = runtimeConfig
        self.configService = configService
        self.state = Self.buildState(
            settings: debugSettings.current,
            runtime: runtimeConfig.current,
            config: configService
        )
    }

    /// Called from `.task {}` — listens for settings changes and updates UI state.
    func observeSettings() async {
        for await settings in Observations({ self.debugSettings.current }) {
            let saving = state.saving
            let statusMessage = state.statusMessage
            state = Self.buildState(
                settings: settings,
                runtime: runtimeConfig.current,
                config: configService
            )
            state.saving = saving
            state.statusMessage = statusMessage
        }
    }

    func save(
        backendUrl: String,
        otlpEndpoint: String,
        otlpInstanceId: String,
        otlpApiKey: String
    ) {
        state.saving = true
        state.statusMessage = nil
        debugSettings.saveConfigOverrides(
            backendUrl: backendUrl.isEmpty ? nil : backendUrl,
            otlpEndpoint: otlpEndpoint.isEmpty ? nil : otlpEndpoint,
            otlpInstanceId: otlpInstanceId.isEmpty ? nil : otlpInstanceId,
            otlpApiKey: otlpApiKey.isEmpty ? nil : otlpApiKey
        )
        state.saving = false
        state.statusMessage = "Saved. Kill and relaunch the app for changes to take effect."
    }

    func clear() {
        state.saving = true
        state.statusMessage = nil
        debugSettings.saveConfigOverrides(
            backendUrl: nil,
            otlpEndpoint: nil,
            otlpInstanceId: nil,
            otlpApiKey: nil
        )
        state.saving = false
        state.statusMessage = "Overrides cleared. Kill and relaunch to use defaults."
    }

    private static func buildState(
        settings: DebugSettings,
        runtime: RuntimeConfig,
        config: ConfigService
    ) -> ConfigUiState {
        ConfigUiState(
            backendInUse: runtime.backendBaseUrl,
            otlpInUse: runtime.otlpEndpoint,
            otlpInstanceIdInUse: runtime.otlpInstanceId,
            otlpApiKeyInUse: runtime.otlpApiKey,
            defaultBackend: config.baseURL,
            defaultOtlp: config.otlpEndpoint ?? "",
            defaultOtlpInstanceId: config.otlpInstanceId,
            defaultOtlpApiKey: config.otlpApiKey,
            savedBackendOverride: settings.backendUrlOverride,
            savedOtlpOverride: settings.otlpEndpointOverride,
            savedOtlpInstanceIdOverride: settings.otlpInstanceIdOverride,
            savedOtlpApiKeyOverride: settings.otlpApiKeyOverride,
            restartBanner: computeRestartBanner(settings: settings, runtime: runtime)
        )
    }
}
