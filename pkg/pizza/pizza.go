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
	MaxCaloriesPerSlice int      `json:"max_calories_per_slice"`
	MustBeVegetarian    bool     `json:"must_be_vegetarian"`
	ExcludedIngredients []string `json:"excluded_ingredients"`
	ExcludedTools       []string `json:"excluded_tools"`
	MaxNumberOfToppings int      `json:"max_number_of_toppings"`
	MinNumberOfToppings int      `json:"min_number_of_toppings"`
}
