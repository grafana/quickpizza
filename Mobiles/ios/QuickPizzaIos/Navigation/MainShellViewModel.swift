import SwiftUI
import SwiftiePod

let mainShellViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    MainShellViewModel(
        tokenStorage: pod.resolve(tokenStorageProvider)
    )
}

@Observable
class MainShellViewModel {
    private let tokenStorage: TokenStoring
    
    // View state
    var showLogin = false
    var showProfile = false
    var selectedTab = 0
    
    var isAuthenticated: Bool {
        tokenStorage.loadSession().isAuthenticated
    }
    
    init(tokenStorage: TokenStoring) {
        self.tokenStorage = tokenStorage
    }
    
    func showAuthSheet() {
        if isAuthenticated {
            showProfile = true
        } else {
            showLogin = true
        }
    }
}
