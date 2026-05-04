export interface Dough {
  id: number;
  name: string;
  caloriesPerSlice?: number;
}

export interface Ingredient {
  id: number;
  name: string;
  caloriesPerSlice?: number;
  vegetarian?: boolean;
}

export interface Pizza {
  id: number;
  name: string;
  dough: Dough;
  ingredients: Ingredient[];
  tool: string;
}

export interface PizzaRecommendation {
  pizza: Pizza;
  calories?: number;
  vegetarian?: boolean;
}

export function parsePizzaRecommendation(json: Record<string, unknown>): PizzaRecommendation {
  const pizzaObj = json.pizza as Record<string, unknown>;
  const doughObj = (pizzaObj.dough ?? {}) as Record<string, unknown>;
  const ingredientsArr = (pizzaObj.ingredients as Record<string, unknown>[]) ?? [];

  return {
    pizza: {
      id: (pizzaObj.id ?? 0) as number,
      name: (pizzaObj.name ?? '') as string,
      dough: {
        id: (doughObj.ID ?? doughObj.id ?? 0) as number,
        name: (doughObj.name ?? '') as string,
        caloriesPerSlice: doughObj.caloriesPerSlice as number | undefined,
      },
      ingredients: ingredientsArr.map((i) => ({
        id: (i.ID ?? i.id ?? 0) as number,
        name: (i.name ?? '') as string,
        caloriesPerSlice: i.caloriesPerSlice as number | undefined,
        vegetarian: i.vegetarian as boolean | undefined,
      })),
      tool: (pizzaObj.tool ?? '') as string,
    },
    calories: json.calories as number | undefined,
    vegetarian: json.vegetarian as boolean | undefined,
  };
}

function requireNumber(json: Record<string, unknown>, field: string): number {
  const value = json[field];
  if (typeof value !== 'number') {
    throw new Error(`Pizza schema v2 parsing failed: missing number field ${field}`);
  }
  return value;
}

function requireString(json: Record<string, unknown>, field: string): string {
  const value = json[field];
  if (typeof value !== 'string') {
    throw new Error(`Pizza schema v2 parsing failed: missing string field ${field}`);
  }
  return value;
}

/**
 * Parses the upcoming v2 response schema. v2 renames `pizza.name` to
 * `pizza.displayName` and `pizza.tool` to `pizza.tooling`.
 */
export function parsePizzaRecommendationV2(json: Record<string, unknown>): PizzaRecommendation {
  const pizzaObj = json.pizza as Record<string, unknown> | undefined;
  if (!pizzaObj) {
    throw new Error('Pizza schema v2 parsing failed: missing pizza object');
  }
  const doughObj = (pizzaObj.dough ?? {}) as Record<string, unknown>;
  const ingredientsArr = (pizzaObj.ingredients as Record<string, unknown>[]) ?? [];

  return {
    pizza: {
      id: requireNumber(pizzaObj, 'id'),
      name: requireString(pizzaObj, 'displayName'),
      dough: {
        id: (doughObj.ID ?? doughObj.id ?? 0) as number,
        name: (doughObj.name ?? '') as string,
        caloriesPerSlice: doughObj.caloriesPerSlice as number | undefined,
      },
      ingredients: ingredientsArr.map((i) => ({
        id: (i.ID ?? i.id ?? 0) as number,
        name: (i.name ?? '') as string,
        caloriesPerSlice: i.caloriesPerSlice as number | undefined,
        vegetarian: i.vegetarian as boolean | undefined,
      })),
      tool: requireString(pizzaObj, 'tooling'),
    },
    calories: json.calories as number | undefined,
    vegetarian: json.vegetarian as boolean | undefined,
  };
}
