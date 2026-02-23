import SwiftUI
import SwiftiePod

struct DebugView: View {
    @State private var viewModel = pod.resolve(debugViewModelProvider)
    @State private var showCrashConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Debug Tools")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Use these actions to validate OpenTelemetry exception and crash behavior.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, 16)

                VStack(spacing: 12) {
                    Button {
                        viewModel.sendExceptionEvent()
                    } label: {
                        Label("Send logger.exception", systemImage: "exclamationmark.bubble.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        showCrashConfirmation = true
                    } label: {
                        Label("Trigger test crash", systemImage: "bolt.horizontal.circle.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if let lastActionMessage = viewModel.lastActionMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.success)
                        Text(lastActionMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Crash button intentionally terminates the app via fatalError.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
        }
        .background(AppColors.background)
        .alert("Trigger test crash?", isPresented: $showCrashConfirmation) {
            Button("Crash now", role: .destructive) {
                viewModel.triggerCrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately terminate the app.")
        }
    }
}

#Preview {
    DebugView()
}
