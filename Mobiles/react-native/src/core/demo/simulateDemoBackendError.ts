import { apiGet } from '../api/apiClient';
import { getIngredientsDemoErrorHeaders } from '../config/configService';

/** Valid catalog ingredient type from QuickPizza seed data (`testdata.yaml`). */
const DEMO_INGREDIENT_TYPE = 'topping';

export type DemoCatalogRequestResult =
  | { ran: false }
  | { ran: true; ok: true }
  | { ran: true; ok: false; userMessage: string };

/**
 * GET /api/ingredients/{type} with optional `x-error-get-ingredients` (when SIMULATE_DEMO_ERROR).
 * Does not affect pizza recommendation. Requires a logged-in session (catalog auth).
 */
export async function runSimulateDemoCatalogErrorRequest(): Promise<DemoCatalogRequestResult> {
  const extraHeaders = getIngredientsDemoErrorHeaders();
  if (!extraHeaders) {
    return { ran: false };
  }

  try {
    const res = await apiGet(
      `/api/ingredients/${DEMO_INGREDIENT_TYPE}`,
      'simulateDemoBackendError',
      { extraHeaders },
    );

    if (res.ok) {
      return { ran: true, ok: true };
    }

    let body = '';
    try {
      body = await res.text();
    } catch {
      /* ignore */
    }
    const snippet = body.trim().slice(0, 200);
    const userMessage =
      snippet.length > 0
        ? `Catalog demo request failed (${res.status}): ${snippet}`
        : `Catalog demo request failed (HTTP ${res.status}). Simulated http error expected when demo flag enabled.`;

    return { ran: true, ok: false, userMessage };
  } catch {
    return {
      ran: true,
      ok: false,
      userMessage:
        'Catalog demo request failed: network or request error. Pizza flow is unaffected.',
    };
  }
}
