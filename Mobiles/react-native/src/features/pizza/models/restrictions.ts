export interface Restrictions {
  maxCaloriesPerSlice: number;
  mustBeVegetarian: boolean;
  excludedIngredients: string[];
  excludedTools: string[];
  maxNumberOfToppings: number;
  minNumberOfToppings: number;
  customName: string;
}

export const defaultRestrictions: Restrictions = {
  maxCaloriesPerSlice: 1000,
  mustBeVegetarian: false,
  excludedIngredients: [],
  excludedTools: [],
  maxNumberOfToppings: 5,
  minNumberOfToppings: 2,
  customName: '',
};

export function restrictionsToJson(r: Restrictions): Record<string, unknown> {
  return {
    maxCaloriesPerSlice: r.maxCaloriesPerSlice,
    mustBeVegetarian: r.mustBeVegetarian,
    excludedIngredients: r.excludedIngredients,
    excludedTools: r.excludedTools,
    maxNumberOfToppings: r.maxNumberOfToppings,
    minNumberOfToppings: r.minNumberOfToppings,
    customName: r.customName,
  };
}
