import { create } from 'zustand';

import { setApiClientTokenGetter } from '../../../core/api/apiClient';
import { setUser, trackEvent } from '../../../core/o11y/o11yEvents';
import * as tokenStorage from '../../../core/storage/tokenStorage';
import * as authRepository from './authRepository';

export interface AuthState {
  isLoggedIn: boolean;
  username: string | null;
  isLoading: boolean;
  errorMessage: string | null;
}

interface AuthStore extends AuthState {
  login: (username: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
  restoreSession: () => Promise<void>;
  clearError: () => void;
}

export const useAuthStore = create<AuthStore>((set, get) => ({
  isLoggedIn: false,
  username: null,
  isLoading: false,
  errorMessage: null,

  login: async (username: string, password: string) => {
    set({ isLoading: true, errorMessage: null });

    const success = await authRepository.login(username, password);

    if (success) {
      setUser({ id: username, username });
      set({ isLoggedIn: true, username, isLoading: false });
      return true;
    } else {
      set({
        isLoading: false,
        errorMessage: 'Login failed. Please check your credentials.',
      });
      return false;
    }
  },

  logout: async () => {
    const username = get().username;
    trackEvent('user_logged_out', { username: username ?? '' });
    setUser({});
    await authRepository.logout();
    set({ isLoggedIn: false, username: null });
  },

  restoreSession: async () => {
    const session = await authRepository.loadSession();
    if (tokenStorage.isValidSession(session)) {
      set({ isLoggedIn: true, username: session.username });
    }
  },

  clearError: () => set({ errorMessage: null }),
}));

// Wire API client to get token from storage
setApiClientTokenGetter(async () => {
  const session = await tokenStorage.loadSession();
  return session.token;
});
