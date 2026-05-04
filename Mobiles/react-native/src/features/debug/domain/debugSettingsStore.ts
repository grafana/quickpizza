import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';

const STORAGE_KEY = 'quickpizza_debug_settings_v1';

export interface DebugSettings {
  backendUrlOverride: string;
  faroCollectorUrlOverride: string;
  backendSlowRecommendations: boolean;
  backendErrorRecommendations: boolean;
  backendSlowIngredients: boolean;
  backendErrorIngredients: boolean;
  clientFaultyPizzaJson: boolean;
  clientSkipAuthDependency: boolean;
}

export const DEFAULT_DEBUG_SETTINGS: DebugSettings = {
  backendUrlOverride: '',
  faroCollectorUrlOverride: '',
  backendSlowRecommendations: false,
  backendErrorRecommendations: false,
  backendSlowIngredients: false,
  backendErrorIngredients: false,
  clientFaultyPizzaJson: false,
  clientSkipAuthDependency: false,
};

interface DebugSettingsStore {
  settings: DebugSettings;
  loaded: boolean;
  load: () => Promise<void>;
  update: (patch: Partial<DebugSettings>) => Promise<void>;
  reset: () => Promise<void>;
}

function sanitizeSettings(value: unknown): DebugSettings {
  if (value == null || typeof value !== 'object') {
    return DEFAULT_DEBUG_SETTINGS;
  }

  const raw = value as Partial<DebugSettings>;
  return {
    backendUrlOverride: String(raw.backendUrlOverride ?? '').trim(),
    faroCollectorUrlOverride: String(raw.faroCollectorUrlOverride ?? '').trim(),
    backendSlowRecommendations: raw.backendSlowRecommendations === true,
    backendErrorRecommendations: raw.backendErrorRecommendations === true,
    backendSlowIngredients: raw.backendSlowIngredients === true,
    backendErrorIngredients: raw.backendErrorIngredients === true,
    clientFaultyPizzaJson: raw.clientFaultyPizzaJson === true,
    clientSkipAuthDependency: raw.clientSkipAuthDependency === true,
  };
}

export async function loadSavedDebugSettings(): Promise<DebugSettings> {
  try {
    const saved = await AsyncStorage.getItem(STORAGE_KEY);
    if (!saved) {
      return DEFAULT_DEBUG_SETTINGS;
    }
    return sanitizeSettings(JSON.parse(saved));
  } catch {
    return DEFAULT_DEBUG_SETTINGS;
  }
}

async function saveDebugSettings(settings: DebugSettings): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
}

export const useDebugSettingsStore = create<DebugSettingsStore>((set, get) => ({
  settings: DEFAULT_DEBUG_SETTINGS,
  loaded: false,

  load: async () => {
    const settings = await loadSavedDebugSettings();
    set({ settings, loaded: true });
  },

  update: async (patch) => {
    const settings = sanitizeSettings({ ...get().settings, ...patch });
    set({ settings, loaded: true });
    await saveDebugSettings(settings);
  },

  reset: async () => {
    set({ settings: DEFAULT_DEBUG_SETTINGS, loaded: true });
    await AsyncStorage.removeItem(STORAGE_KEY);
  },
}));

export function getDebugSettingsSnapshot(): DebugSettings {
  return useDebugSettingsStore.getState().settings;
}

export function getErrorInjectionHeaders(): Record<string, string> {
  const settings = getDebugSettingsSnapshot();
  const headers: Record<string, string> = {};

  if (settings.backendErrorRecommendations) {
    headers['x-error-record-recommendation'] =
      'simulated recommendation service failure';
  }
  if (settings.backendErrorIngredients) {
    headers['x-error-get-ingredients'] =
      'simulated ingredient lookup failure';
  }
  if (settings.backendSlowRecommendations) {
    headers['x-delay-record-recommendation'] = '3s';
  }
  if (settings.backendSlowIngredients) {
    headers['x-delay-get-ingredients'] = '750ms';
  }

  return headers;
}
