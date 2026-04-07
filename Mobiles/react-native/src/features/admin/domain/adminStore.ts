import { create } from 'zustand';

import type { AdminPizza } from '../../../core/api/adminApi';
import {
  adminLogin as adminLoginApi,
  getAdminRecommendations,
} from '../../../core/api/adminApi';
import * as adminStorage from '../../../core/storage/adminStorage';

export interface AdminState {
  isLoggedIn: boolean;
  isLoading: boolean;
  loginError: string | null;
  recommendations: AdminPizza[];
  recommendationsLoading: boolean;
}

interface AdminStore extends AdminState {
  login: (username: string, password: string) => Promise<boolean>;
  logout: () => Promise<void>;
  restoreSession: () => Promise<void>;
  fetchRecommendations: () => Promise<void>;
  clearLoginError: () => void;
}

export const useAdminStore = create<AdminStore>((set, get) => ({
  isLoggedIn: false,
  isLoading: false,
  loginError: null,
  recommendations: [],
  recommendationsLoading: false,

  login: async (username: string, password: string) => {
    set({ isLoading: true, loginError: null });

    const result = await adminLoginApi(username, password);

    if (result) {
      await adminStorage.saveAdminToken(result.token);
      set({ isLoggedIn: true, isLoading: false });
      get().fetchRecommendations();
      return true;
    } else {
      set({
        isLoading: false,
        loginError: 'Login failed. Please check your credentials.',
      });
      return false;
    }
  },

  logout: async () => {
    await adminStorage.clearAdminToken();
    set({ isLoggedIn: false, recommendations: [] });
  },

  restoreSession: async () => {
    const token = await adminStorage.loadAdminToken();
    if (token) {
      set({ isLoggedIn: true });
      get().fetchRecommendations();
    }
  },

  fetchRecommendations: async () => {
    const token = await adminStorage.loadAdminToken();
    if (!token) return;

    set({ recommendationsLoading: true });
    const data = await getAdminRecommendations(token);
    set({
      recommendations: data?.pizzas ?? [],
      recommendationsLoading: false,
    });
  },

  clearLoginError: () => set({ loginError: null }),
}));
