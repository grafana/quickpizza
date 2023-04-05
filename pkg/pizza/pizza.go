package pizza

type Pizza struct {
	Name        string       `json:"name"`
	Dough       Dough        `json:"dough"`
	Ingredients []Ingredient `json:"ingredients"`
	Tool        string       `json:"tool"`
}

type Dough struct {
	Name             string `json:"name"`
	CaloriesPerSlice int    `json:"caloriesPerSlice"`
}

type Ingredient struct {
	Name             string `json:"name"`
	CaloriesPerSlice int    `json:"caloriesPerSlice"`
	Vegetarian       bool   `json:"vegetarian"`
}

func (p Pizza) IsVegetarian() bool {
	for _, ingredient := range p.Ingredients {
		if !ingredient.Vegetarian {
			return false
		}
	}
	return true
}

func (p Pizza) CalculateCalories() int {
	calories := 0
	for _, ingredient := range p.Ingredients {
		calories += ingredient.CaloriesPerSlice
	}
	return calories
}

type Restrictions struct {
	MaxCaloriesPerSlice int      `json:"maxCaloriesPerSlice"`
	MustBeVegetarian    bool     `json:"mustBeVegetarian"`
	ExcludedIngredients []string `json:"excludedIngredients"`
	ExcludedTools       []string `json:"excludedTools"`
	MaxNumberOfToppings int      `json:"maxNumberOfToppings"`
	MinNumberOfToppings int      `json:"minNumberOfToppings"`
}
