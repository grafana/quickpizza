import SwiftUI
import SwiftiePod

/// Main app shell with bottom tab navigation and shared app bar.
struct MainShell: View {
    @State private var viewModel = pod.resolve(mainShellViewModelProvider)

    var body: some View {
        NavigationStack {
            TabView(selection: $viewModel.selectedTab) {
                // Home tab
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                // About tab
                AboutView()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
                    .tag(1)
            }
            .tint(AppColors.primary)
            .toolbar {
                QuickPizzaToolbar(isAuthenticated: viewModel.isAuthenticated) {
                    viewModel.showAuthSheet()
                }
            }
        }
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
