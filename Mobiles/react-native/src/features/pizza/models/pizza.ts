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
