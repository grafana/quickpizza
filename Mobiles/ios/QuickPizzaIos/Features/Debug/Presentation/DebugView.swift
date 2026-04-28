import SwiftUI
import SwiftiePod

struct DebugView: View {
    @State private var viewModel = pod.resolve(debugViewModelProvider)
    @State private var showConfig = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RestartRequiredBanner(state: viewModel.state.restartBanner)

                ConfigEntryCard { showConfig = true }

                Text("Use these tools to simulate issues and exercise the observability instrumentation during demos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ErrorSimulationSection(viewModel: viewModel)

                ClientDiagnosticsSection(viewModel: viewModel)

                if let message = viewModel.state.lastActionMessage {
                    LastActionCard(message: message)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(AppColors.background)
        .trackScreenView("debug")
        .navigationTitle("Debug")
        .toolbar {
            if viewModel.state.settings.hasActiveOverrides {
                Button("Reset All") { viewModel.resetAll() }
            }
        }
        .navigationDestination(isPresented: $showConfig) {
            ConfigView()
        }
        .task {
            await viewModel.observeSettings()
        }
        .onChange(of: viewModel.state.lastActionMessage) { _, newValue in
            if newValue != nil {
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.clearLastAction()
                }
            }
        }
    }
}

// MARK: - Config Entry Card

private struct ConfigEntryCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Config")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Change backend URL, OTLP endpoint, and OTLP credentials (requires restart)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error Simulation Section

private struct ErrorSimulationSection: View {
    let viewModel: DebugViewModel

    var body: some View {
        SectionHeader("Error Simulation")
        Text("Toggle these to simulate backend issues, client-side faults, and version drift. Takes effect immediately — no restart needed.")
            .font(.caption)
            .foregroundStyle(.secondary)

        VStack(spacing: 0) {
            ToggleRow(title: "Slow Recommendations", subtitle: "Adds delay to pizza recommendations", isOn: viewModel.state.settings.slowRecommendations) {
                viewModel.setSlowRecommendations($0)
            }
            Divider()
            ToggleRow(title: "Slow Ingredients", subtitle: "Adds delay to ingredient loading", isOn: viewModel.state.settings.slowIngredients) {
                viewModel.setSlowIngredients($0)
            }
            Divider()
            ToggleRow(title: "Error on Recommendations", subtitle: "Forces server errors on recommendations", isOn: viewModel.state.settings.errorOnRecommendations) {
                viewModel.setErrorOnRecommendations($0)
            }
            Divider()
            ToggleRow(title: "Error on Ingredients", subtitle: "Forces server errors on ingredient loading", isOn: viewModel.state.settings.errorOnIngredients) {
                viewModel.setErrorOnIngredients($0)
            }
            Divider()
            ToggleRow(title: "Use v2 pizza response schema", subtitle: "Experimental — simulates a client/backend schema drift", isOn: viewModel.state.settings.useV2PizzaSchema) {
                viewModel.setUseV2PizzaSchema($0)
            }
            Divider()
            ToggleRow(title: "Skip auth dep in tools provider", subtitle: "Tools list won't refresh on login/logout — reproduces the bug", isOn: viewModel.state.settings.skipAuthDepInTools) {
                viewModel.setSkipAuthDepInTools($0)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Client Diagnostics Section

private struct ClientDiagnosticsSection: View {
    let viewModel: DebugViewModel

    var body: some View {
        SectionHeader("Client Diagnostics")

        QuickSignalsCard(viewModel: viewModel)

        DiagnosticActionCard(
            title: "Handled Exception",
            description: "Throws an exception inside a try/catch and reports it via the OTel logger as an exception log record. Tests the manual reporting path.",
            buttonText: "Send Handled Exception",
            action: viewModel.logTestException
        )

        CrashCard(viewModel: viewModel)
    }
}

// MARK: - Quick Signals Card

private struct QuickSignalsCard: View {
    let viewModel: DebugViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Signals").font(.headline)
            Text("Emit one-off signals (logs and custom events) to verify the OTel pipeline end-to-end.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer().frame(height: 4)
            Button("Send Debug Log") { viewModel.sendDebugLog() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Send Error Log") { viewModel.sendErrorLog() }
                .buttonStyle(PrimaryButtonStyle())
            Button("Send Custom Event") { viewModel.sendCustomEvent() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Diagnostic Action Card

private struct DiagnosticActionCard: View {
    let title: String
    let description: String
    let buttonText: String
    let action: () -> Void
    var danger: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
                .foregroundStyle(danger ? Color.red : .primary)
            Text(description)
                .font(.caption)
                .foregroundStyle(danger ? Color.red.opacity(0.85) : .secondary)
            Spacer().frame(height: 4)
            if danger {
                Button(buttonText, action: action)
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                Button(buttonText, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .background(danger ? Color.red.opacity(0.08) : AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Crash Card

private enum CrashKind: Identifiable {
    case fatalError
    case forceUnwrap

    var id: String {
        switch self {
        case .fatalError: return "fatalError"
        case .forceUnwrap: return "forceUnwrap"
        }
    }

    var dialogTitle: String {
        switch self {
        case .fatalError: return "Trigger crash?"
        case .forceUnwrap: return "Trigger simulated nil force-unwrap?"
        }
    }

    var dialogBody: String {
        switch self {
        case .fatalError:
            return "The app will terminate. Relaunch it after the crash. MetricKit crash diagnostics are delivered by iOS later and may not appear immediately in your observability backend."
        case .forceUnwrap:
            return "Simulates a real-world nil-dereference bug. Relaunch after the crash. MetricKit crash diagnostics are delivered by iOS later and may not appear immediately in your observability backend."
        }
    }
}

private struct CrashCard: View {
    let viewModel: DebugViewModel
    @State private var pending: CrashKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Crash Reporting").font(.headline).foregroundStyle(.red)
            Text("Terminates the app to exercise iOS MetricKit crash diagnostics. MetricKit delivery is OS-managed and can be delayed; manual crashes may not show up in Grafana Cloud immediately. Use Xcode's simulated MetricKit payload to verify the OTel export path.")
                .font(.caption)
                .foregroundStyle(Color.red.opacity(0.85))
            Spacer().frame(height: 4)
            Button("Crash (fatalError)") { pending = .fatalError }
                .buttonStyle(SecondaryButtonStyle())
            Button("Crash (force-unwrap nil)") { pending = .forceUnwrap }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .alert(item: $pending) { kind in
            Alert(
                title: Text(kind.dialogTitle),
                message: Text(kind.dialogBody),
                primaryButton: .destructive(Text("Crash now")) {
                    switch kind {
                    case .fatalError: viewModel.triggerCrashFatalError()
                    case .forceUnwrap: viewModel.triggerCrashForceUnwrap()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

// MARK: - Reusable Building Blocks

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let onChanged: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: onChanged)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct LastActionCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.91, green: 0.96, blue: 0.91))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Restart Required Banner

struct RestartRequiredBanner: View {
    let state: RestartBannerState

    var body: some View {
        if case .visible(let changedLabel) = state {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(red: 0.48, green: 0.31, blue: 0.0))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Restart required")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.48, green: 0.31, blue: 0.0))
                    Text("Kill and relaunch the app for the new \(changedLabel) to take effect.")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.48, green: 0.31, blue: 0.0))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.0, green: 0.93, blue: 0.70))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    DebugView()
}
