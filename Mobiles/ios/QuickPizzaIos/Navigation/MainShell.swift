import SwiftUI
import SwiftiePod

/// Main app shell with bottom tab navigation and shared app bar.
struct MainShell: View {
    @State private var viewModel = pod.resolve(mainShellViewModelProvider)

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            // Home tab
            NavigationStack {
                HomeView()
                    .toolbar {
                        QuickPizzaToolbar(isAuthenticated: viewModel.isAuthenticated) {
                            viewModel.showAuthSheet()
                        }
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // About tab
            NavigationStack {
                AboutView()
                    .toolbar {
                        QuickPizzaToolbar(isAuthenticated: viewModel.isAuthenticated) {
                            viewModel.showAuthSheet()
                        }
                    }
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(1)
        }
        .tint(AppColors.primary)
        .sheet(isPresented: $viewModel.showLogin) {
            LoginView()
        }
        .sheet(isPresented: $viewModel.showProfile) {
            ProfileView()
        }
    }
}

#Preview {
    MainShell()
}
