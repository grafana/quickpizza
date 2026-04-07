import { apiDelete, apiGet, apiPost } from '../../../core/api/apiClient';
import { addMeasurement } from '../../../core/o11y/o11yMetrics';

export interface Rating {
  id: number;
  pizzaId: number;
  stars: number;
}

export async function ratePizza(pizzaId: number, stars: number): Promise<boolean> {
  try {
    const response = await apiPost('/api/ratings', { pizza_id: pizzaId, stars });

    if (response.status === 201 || response.status === 200) {
      addMeasurement('pizza.rating', { pizza_id: pizzaId, stars });
      return true;
    }

    if (response.status === 401) {
      throw new Error('You may need to be logged in');
    }

    if (response.status === 403) {
      const json = (await response.json()) as { error?: string };
      throw new Error(json.error ?? "You don't have permission to do this operation");
    }

    throw new Error('Failed to rate pizza. Please try again.');
  } catch (error) {
    throw error;
  }
}

export async function getRatings(): Promise<Rating[]> {
  try {
    const response = await apiGet('/api/ratings', 'getRatings');
    if (response.ok) {
      const json = (await response.json()) as { ratings?: { id: number; pizza_id: number; stars: number }[] };
      return (json.ratings ?? []).map((r) => ({
        id: r.id,
        pizzaId: r.pizza_id,
        stars: r.stars,
      }));
    }
    return [];
  } catch {
    return [];
  }
}

export async function deleteRatings(): Promise<boolean> {
  try {
    const response = await apiDelete('/api/ratings');
    if (response.status === 200 || response.status === 204) {
      return true;
    }
    if (response.status === 401) {
      throw new Error('You may need to be logged in');
    }
    if (response.status === 403) {
      const json = (await response.json()) as { error?: string };
      throw new Error(json.error ?? "You don't have permission");
    }
    throw new Error('Failed to delete ratings.');
  } catch (error) {
    throw error;
  }
}
