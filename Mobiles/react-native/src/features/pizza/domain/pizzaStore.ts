import { create } from 'zustand';

import { useAuthStore } from '../../auth/domain/authStore';
import { trackEvent } from '../../../core/o11y/o11yEvents';
import { addMeasurement } from '../../../core/o11y/o11yMetrics';
import type { PizzaRecommendation } from '../models/pizza';
import type { Restrictions } from '../models/restrictions';
import * as pizzaRepository from './pizzaRepository';

export interface PizzaState {
  pizza: PizzaRecommendation | null;
  isLoading: boolean;
  errorMessage: string | null;
}

interface PizzaStore extends PizzaState {
  getPizza: (restrictions: Restrictions) => Promise<void>;
  clearPizza: () => void;
}

export const usePizzaStore = create<PizzaStore>((set, get) => ({
  pizza: null,
  isLoading: false,
  errorMessage: null,

  getPizza: async (restrictions: Restrictions) => {
    trackEvent('pizza_requested', {
      vegetarian: String(restrictions.mustBeVegetarian),
    });
    set({ isLoading: true, errorMessage: null });

    try {
      const pizza = await pizzaRepository.getPizzaRecommendation(restrictions);

      if (pizza != null) {
        trackEvent('pizza_received', {
          pizza_id: String(pizza.pizza.id),
          pizza_name: pizza.pizza.name,
        });
        addMeasurement('pizza.recommendation', {
          pizza_id: pizza.pizza.id,
          calories: pizza.calories ?? 0,
          vegetarian: pizza.vegetarian === true ? 1 : 0,
        });
        set({ pizza, isLoading: false });
      } else {
        set({
          isLoading: false,
          errorMessage:
            'Failed to get pizza recommendation. Please log in and try again.',
        });
      }
    } catch (error) {
      set({
        isLoading: false,
        errorMessage: error instanceof Error ? error.message : String(error),
      });
    }
  },

  clearPizza: () => set({ pizza: null, errorMessage: null }),
}));

// Reset pizza when user logs out
let wasLoggedIn = useAuthStore.getState().isLoggedIn;
useAuthStore.subscribe((state) => {
  if (wasLoggedIn && !state.isLoggedIn) {
    usePizzaStore.getState().clearPizza();
  }
  wasLoggedIn = state.isLoggedIn;
});
