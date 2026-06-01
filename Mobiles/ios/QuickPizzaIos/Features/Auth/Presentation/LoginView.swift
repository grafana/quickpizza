import SwiftUI
import SwiftiePod

struct LoginView: View {
    @State private var viewModel = pod.resolve(loginViewModelProvider)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Avatar
                    Circle()
                        .fill(AppColors.primaryLight)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppColors.primary)
                        )

                    // Welcome text
                    VStack(spacing: 8) {
                        Text("Welcome to QuickPizza")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Sign in to save your favorite pizzas")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    // Login card
                    VStack(spacing: 16) {
                        // Username
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(AppColors.textSecondary)
                            TextField("Username", text: $viewModel.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .username)
                                .onSubmit {
                                    focusedField = .password
                                }
                        }
                        .padding(14)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .username
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Username")

                        // Password
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(AppColors.textSecondary)
                            SecureField("Password", text: $viewModel.password)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    Task { await viewModel.login() }
                                }
                        }
                        .padding(14)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedField = .password
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Password")

                        // Error message
                        if let error = viewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(AppColors.error)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.error)
                                Spacer()
                            }
                            .padding(12)
                            .background(AppColors.error.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Sign In button
                        Button {
                            Task { await viewModel.login() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isLoading)
                    }
                    .cardStyle()

                    // Hint
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Hint: Use \"default\" / \"12345678\" to login")
                            .font(.caption)
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.orange)
                        Text("To clear ratings, use \"studio-user\" / \"k6studiorocks\" (the default user cannot delete ratings).")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.00))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Tip: You can create a new user via the POST http://quickpizza.grafana.com/api/users endpoint. Attach a JSON payload with username and password keys.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(24)
            }
            .background(AppColors.background)
            .trackScreenView("login")
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: viewModel.loginSucceeded) { _, succeeded in
                if succeeded { dismiss() }
            }
        }
    }
}

#Preview {
    LoginView()
}
