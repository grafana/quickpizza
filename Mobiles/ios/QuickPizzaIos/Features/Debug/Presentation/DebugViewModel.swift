import Foundation
import Observation
import SwiftUI
import SwiftiePod

let debugViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    DebugViewModel(
        debugSettings: pod.resolve(debugSettingsRepositoryProvider),
        runtimeConfig: pod.resolve(runtimeConfigHolderProvider),
        logger: pod.resolve(loggerProvider),
        events: pod.resolve(appEventsProvider)
    )
}

private let DEBUG_TAB_CONTEXT: [String: String] = ["debug.source": "debug_tab"]

// MARK: - UI State

struct DebugUiState: Equatable {
    var settings: DebugSettings = DebugSettings()
    var restartBanner: RestartBannerState = .hidden
    var lastActionMessage: String? = nil
}

enum RestartBannerState: Equatable {
    case hidden
    case visible(changedLabel: String)
}

/// Computes whether the persisted overrides differ from the URLs/credentials
/// actually in use this session. Shared by `DebugViewModel` and
/// `ConfigViewModel` so the banner is consistent on both screens.
func computeRestartBanner(
    settings: DebugSettings,
    runtime: RuntimeConfig
) -> RestartBannerState {
    let savedBackend = settings.backendUrlOverride ?? runtime.backendBaseUrl
    let savedOtlp = settings.otlpEndpointOverride ?? runtime.otlpEndpoint
    let savedInstanceId = settings.otlpInstanceIdOverride ?? runtime.otlpInstanceId
    let savedApiKey = settings.otlpApiKeyOverride ?? runtime.otlpApiKey

    let changedFields = [
        savedBackend != runtime.backendBaseUrl ? "Backend URL" : nil,
        savedOtlp != runtime.otlpEndpoint ? "OTLP endpoint" : nil,
        savedInstanceId != runtime.otlpInstanceId ? "OTLP instance ID" : nil,
        savedApiKey != runtime.otlpApiKey ? "OTLP API key" : nil,
    ].compactMap { $0 }

    if changedFields.isEmpty {
        return .hidden
    } else {
        return .visible(changedLabel: changedFields.joined(separator: ", "))
    }
}

// MARK: - ViewModel

@Observable
class DebugViewModel {
    private let debugSettings: DebugSettingsRepository
    private let runtimeConfig: RuntimeConfigHolder
    private let logger: Logging
    private let events: AppEvents

    var state: DebugUiState

    init(
        debugSettings: DebugSettingsRepository,
        runtimeConfig: RuntimeConfigHolder,
        logger: Logging,
        events: AppEvents
    ) {
        self.debugSettings = debugSettings
        self.runtimeConfig = runtimeConfig
        self.logger = logger
        self.events = events
        self.state = DebugUiState(
            settings: debugSettings.current,
            restartBanner: computeRestartBanner(
                settings: debugSettings.current,
                runtime: runtimeConfig.current
            )
        )
    }

    /// Called from `.task {}` — listens for settings changes and updates UI state.
    func observeSettings() async {
        for await settings in Observations({ self.debugSettings.current }) {
            state.settings = settings
            state.restartBanner = computeRestartBanner(
                settings: settings,
                runtime: runtimeConfig.current
            )
        }
    }

    // MARK: Toggles (persisted)

    func setSlowRecommendations(_ value: Bool) { debugSettings.setSlowRecommendations(value) }
    func setSlowIngredients(_ value: Bool) { debugSettings.setSlowIngredients(value) }
    func setErrorOnRecommendations(_ value: Bool) { debugSettings.setErrorOnRecommendations(value) }
    func setErrorOnIngredients(_ value: Bool) { debugSettings.setErrorOnIngredients(value) }
    func setUseV2PizzaSchema(_ value: Bool) { debugSettings.setUseV2PizzaSchema(value) }
    func setSkipAuthDepInTools(_ value: Bool) { debugSettings.setSkipAuthDepInTools(value) }

    func resetAll() {
        debugSettings.resetAll()
        showAction("All debug settings reset")
    }

    // MARK: Quick Signals

    func sendDebugLog() {
        logger.debug(
            "Test debug log from Debug tab",
            attributes: DEBUG_TAB_CONTEXT.merging(["debug.action": "logger.debug"]) { _, new in new }
        )
        showAction("Sent debug log")
    }

    func sendErrorLog() {
        logger.error(
            "Test error log from Debug tab",
            attributes: DEBUG_TAB_CONTEXT.merging(["debug.action": "logger.error"]) { _, new in new }
        )
        showAction("Sent error log")
    }

    func sendCustomEvent() {
        events.trackEvent(
            "debug.test_event",
            attributes: DEBUG_TAB_CONTEXT.merging(["debug.action": "events.trackEvent"]) { _, new in new }
        )
        showAction("Sent custom event")
    }

    // MARK: Diagnostics

    func logTestException() {
        let error = DebugTestError.simulatedException
        logger.exception(
            "Test exception triggered by user",
            error: error,
            attributes: DEBUG_TAB_CONTEXT.merging(["debug.action": "logger.exception"]) { _, new in new }
        )
        showAction("Sent handled exception")
    }

    /// Crashes the app via `fatalError`. The OTel crash reporter persists
    /// the crash to disk; the exporter delivers it on the next app launch.
    func triggerCrashFatalError() -> Never {
        logger.error(
            "Debug tab is about to trigger a fatalError crash",
            attributes: DEBUG_TAB_CONTEXT.merging(["debug.action": "crash_fatal_error"]) { _, new in new }
        )
        fatalError("Debug crash triggered from Debug tab (fatalError)")
    }

    /// Crashes via force-unwrapping nil — exercises the same crash pipeline
    /// but mirrors a real-world nil-dereference bug.
    func triggerCrashForceUnwrap() {
        logger.error(
            "Debug tab is about to trigger a force-unwrap crash",
            attributes: DEBUG_TAB_CONTEXT.merging(["debug.action": "crash_force_unwrap"]) { _, new in new }
        )
        let nothing: String? = nil
        _ = nothing!.count
    }

    // MARK: Helpers

    func clearLastAction() {
        state.lastActionMessage = nil
    }

    private func showAction(_ message: String) {
        state.lastActionMessage = message
    }
}

enum DebugTestError: LocalizedError {
    case simulatedException

    var errorDescription: String? {
        "Simulated exception from Debug tab"
    }
}
