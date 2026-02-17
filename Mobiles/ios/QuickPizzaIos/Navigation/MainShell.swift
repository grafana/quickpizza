import SwiftUI

/// Main app shell with bottom tab navigation and shared app bar.
struct MainShell: View {
    @State private var showLogin = false
    @State private var showProfile = false
    @State private var selectedTab = 0

    // Check auth state to decide login vs profile
    private var isAuthenticated: Bool {
        let session = UserDefaultsTokenStorage().loadSession()
        return session.isAuthenticated
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab
            NavigationStack {
                HomeView()
                    .toolbar {
                        QuickPizzaToolbar {
                            if isAuthenticated {
                                showProfile = true
                            } else {
                                showLogin = true
                            }
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
                        QuickPizzaToolbar {
                            if isAuthenticated {
                                showProfile = true
                            } else {
                                showLogin = true
                            }
                        }
                    }
            }
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
            .tag(1)
        }
        .tint(AppColors.primary)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }
}

#Preview {
    MainShell()
}
