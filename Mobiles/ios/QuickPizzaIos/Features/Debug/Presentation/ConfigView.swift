import SwiftUI
import SwiftiePod

struct ConfigView: View {
    @State private var viewModel = pod.resolve(configViewModelProvider)
    @State private var backendField = ""
    @State private var otlpField = ""
    @State private var instanceIdField = ""
    @State private var apiKeyField = ""
    @State private var apiKeyRevealed = false
    @State private var didSeedFields = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RestartRequiredBanner(state: viewModel.state.restartBanner)

                Text("Override the URLs and OTLP credentials used by this app. Changes only take effect after you kill and restart the app — this keeps traces, logs and metrics correlated within a single session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ConfigField(
                    label: "Backend URL",
                    inUseValue: viewModel.state.backendInUse,
                    defaultValue: viewModel.state.defaultBackend,
                    hintText: "http://192.168.1.100:3333",
                    value: $backendField,
                    keyboardType: .URL
                )

                ConfigField(
                    label: "OTLP endpoint",
                    inUseValue: viewModel.state.otlpInUse,
                    defaultValue: viewModel.state.defaultOtlp,
                    hintText: "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp",
                    value: $otlpField,
                    keyboardType: .URL
                )

                ConfigField(
                    label: "OTLP instance ID",
                    inUseValue: viewModel.state.otlpInstanceIdInUse,
                    defaultValue: viewModel.state.defaultOtlpInstanceId,
                    hintText: "1234567",
                    value: $instanceIdField,
                    keyboardType: .numberPad,
                    supportingText: "Numeric ID from your Grafana Cloud OTLP Gateway integration."
                )

                SecretField(
                    label: "OTLP API key",
                    inUseValue: viewModel.state.otlpApiKeyInUse,
                    defaultValue: viewModel.state.defaultOtlpApiKey,
                    value: $apiKeyField,
                    revealed: $apiKeyRevealed,
                    supportingText: "Combined with the instance ID to build Authorization: Basic base64(instanceId:apiKey)."
                )

                Button {
                    viewModel.save(
                        backendUrl: backendField,
                        otlpEndpoint: otlpField,
                        otlpInstanceId: instanceIdField,
                        otlpApiKey: apiKeyField
                    )
                } label: {
                    if viewModel.state.saving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.state.saving)

                Button {
                    viewModel.clear()
                    backendField = ""
                    otlpField = ""
                    instanceIdField = ""
                    apiKeyField = ""
                } label: {
                    Text("Use defaults (clear overrides)")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.state.saving)

                if let statusMessage = viewModel.state.statusMessage {
                    StatusCard(message: statusMessage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(AppColors.background)
        .navigationTitle("Config")
        .task {
            if !didSeedFields {
                backendField = viewModel.state.savedBackendOverride ?? ""
                otlpField = viewModel.state.savedOtlpOverride ?? ""
                instanceIdField = viewModel.state.savedOtlpInstanceIdOverride ?? ""
                apiKeyField = viewModel.state.savedOtlpApiKeyOverride ?? ""
                didSeedFields = true
            }
            await viewModel.observeSettings()
        }
    }
}

// MARK: - Config Field

private struct ConfigField: View {
    let label: String
    let inUseValue: String
    let defaultValue: String
    let hintText: String
    @Binding var value: String
    var keyboardType: UIKeyboardType = .default
    var supportingText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)

            LabelledMonoLine(label: "Currently in use", value: inUseValue.isEmpty ? "(not set)" : inUseValue)
            if defaultValue != inUseValue {
                LabelledMonoLine(label: "Default", value: defaultValue.isEmpty ? "(not set)" : defaultValue)
            }

            TextField("Override (empty = use default)", text: $value, prompt: Text(hintText))
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            if let supportingText {
                Text(supportingText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Secret Field

private struct SecretField: View {
    let label: String
    let inUseValue: String
    let defaultValue: String
    @Binding var value: String
    @Binding var revealed: Bool
    var supportingText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)

            LabelledMonoLine(label: "Currently in use", value: maskSecret(inUseValue))
            if defaultValue != inUseValue {
                LabelledMonoLine(label: "Default", value: maskSecret(defaultValue))
            }

            HStack {
                Group {
                    if revealed {
                        TextField("Override (empty = use default)", text: $value, prompt: Text("glc_xxxxxxxxxxxx"))
                    } else {
                        SecureField("Override (empty = use default)", text: $value, prompt: Text("glc_xxxxxxxxxxxx"))
                    }
                }
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()

                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                }
            }

            if let supportingText {
                Text(supportingText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private func maskSecret(_ value: String) -> String {
    if value.isEmpty { return "(not set)" }
    if value.count <= 8 { return String(repeating: "•", count: max(value.count, 4)) }
    let head = String(value.prefix(4))
    let tail = String(value.suffix(4))
    let middleBullets = min(value.count - 8, 8)
    return head + String(repeating: "•", count: middleBullets) + tail
}

// MARK: - Reusable Components

private struct LabelledMonoLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
        }
    }
}

private struct StatusCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.success)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.91, green: 0.96, blue: 0.91))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ConfigView()
    }
}
