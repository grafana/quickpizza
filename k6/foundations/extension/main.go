package internal

import (
	"fmt"

	"go.k6.io/k6/js/modules"

	"github.com/grafana/quickpizza/pkg/pizza"
)

// init is called by the Go runtime at application startup.
func init() {
	modules.Register("k6/x/internal", new(Internal))
}

// Internal is the type for our custom API.
type Internal struct {
	CheckResult string // textual description of the most recent result
}

type GojaRestrictions struct {
	MaxCaloriesPerSlice int      `json:"maxCaloriesPerSlice"`
	MustBeVegetarian    bool     `json:"mustBeVegetarian"`
	ExcludedIngredients []string `json:"excludedIngredients"`
	ExcludedTools       []string `json:"excludedTools"`
	MinNumberOfToppings int      `json:"minNumberOfToppings"`
	MaxNumberOfToppings int      `json:"maxNumberOfToppings"`
}

// CheckRestrictions checks if the given pizza satisfies the given restrictions.
func (i *Internal) CheckRestrictions(pizza pizza.Pizza, restrictions GojaRestrictions) bool {
	if restrictions.MustBeVegetarian && !pizza.IsVegetarian() {
		i.CheckResult = "Pizza is not vegetarian"
		return false
	}

	if pizza.CalculateCalories() > restrictions.MaxCaloriesPerSlice {
		i.CheckResult = "Pizza has too many calories: expected at most " + fmt.Sprint(restrictions.MaxCaloriesPerSlice) + " but got " + fmt.Sprint(pizza.CalculateCalories())
		return false
	}

	for _, ingredient := range pizza.Ingredients {
		for _, excluded := range restrictions.ExcludedIngredients {
			if ingredient.Name == excluded {
				i.CheckResult = "Pizza has excluded ingredient: " + excluded
				return false
			}
		}
	}

	for _, excluded := range restrictions.ExcludedTools {
		if pizza.Tool == excluded {
			i.CheckResult = "Pizza has excluded tool"
			return false
		}
	}

	// We add 3 to the restrictions because the pizza always has oil, sauce and cheese.
	if len(pizza.Ingredients) > restrictions.MaxNumberOfToppings+3 {
		i.CheckResult = "Pizza has too many toppings: expected at most " + fmt.Sprint(restrictions.MaxNumberOfToppings+3) + " but got " + fmt.Sprint(len(pizza.Ingredients))
		return false
	}

	if len(pizza.Ingredients) < restrictions.MinNumberOfToppings+3 {
		i.CheckResult = "Pizza has too few toppings: expected at least " + fmt.Sprint(restrictions.MinNumberOfToppings+3) + " but got " + fmt.Sprint(len(pizza.Ingredients))
		return false
	}

	i.CheckResult = "Pizza is OK"
	return true
}

// GetCheckResult returns the textual description of the most recent result.
func (i *Internal) GetCheckResult() string {
	return i.CheckResult
}
