import { apiGet, apiPost } from '../../../core/api/apiClient';
import type { PizzaRecommendation } from '../models/pizza';
import { parsePizzaRecommendation } from '../models/pizza';
import type { Restrictions } from '../models/restrictions';
import { restrictionsToJson } from '../models/restrictions';

export async function getQuote(): Promise<string> {
  try {
    const response = await apiGet('/api/quotes', 'getQuote');
    if (response.ok) {
      const json = (await response.json()) as { quotes?: string[] };
      const quotes = json.quotes ?? [];
      return quotes[0] ?? '';
    }
    return '';
  } catch {
    return '';
  }
}

export async function getTools(): Promise<string[]> {
  try {
    const response = await apiGet('/api/tools', 'getTools');
    if (response.ok) {
      const json = (await response.json()) as { tools?: string[] };
      return json.tools ?? [];
    }
    return [];
  } catch {
    return [];
  }
}

export async function getPizzaRecommendation(
  restrictions: Restrictions,
): Promise<PizzaRecommendation | null> {
  try {
    const response = await apiPost('/api/pizza', restrictionsToJson(restrictions));

    if (response.ok) {
      const json = (await response.json()) as Record<string, unknown>;
      return parsePizzaRecommendation(json);
    }

    if (response.status === 401) {
      return null;
    }

    if (response.status === 403) {
      const json = (await response.json()) as { error?: string };
      throw new Error(json.error ?? 'Operation not permitted');
    }

    if (response.status >= 500) {
      throw new Error('Server error - please try again later');
    }

    return null;
  } catch (error) {
    throw error;
  }
}
