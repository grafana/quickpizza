// Shared configuration for every test in this workshop.
//
// Keeping this in one module means the three tests differ only in their load
// profile and in what they assert - not in how they talk to the application.

export const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

// QuickPizza accepts any 16-character token and resolves it to the seeded
// "default" user, so there is no login step to worry about in a workshop.
const TOKEN = __ENV.TOKEN || "abcdef0123456789";

export const headers = {
  "Content-Type": "application/json",
  Authorization: `token ${TOKEN}`,
};

// Returns the parsed response body, or null if it isn't JSON.
//
// A healthy QuickPizza always answers with JSON, but a failing or timing-out
// one may not - and an exception thrown inside a check() callback aborts the
// whole iteration, which would hide the very failure we want to measure.
export function parseJSON(res) {
  try {
    return res.json();
  } catch {
    return null;
  }
}

// The body of POST /api/pizza. Every field is optional; the server fills in
// defaults for the ones we leave out.
//
// Careful with the exclusion lists: QuickPizza matches them against ingredient
// and tool names exactly, so "pepperoni" silently excludes nothing while
// "Pepperoni" works. A good reminder that a request the server accepts is not
// the same as a request the server honours.
export const restrictions = {
  maxCaloriesPerSlice: 500,
  mustBeVegetarian: false,
  excludedIngredients: ["Pepperoni"],
  excludedTools: ["Knife"],
  maxNumberOfToppings: 6,
  minNumberOfToppings: 2,
};
