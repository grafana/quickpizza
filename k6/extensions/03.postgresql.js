import sql from "k6/x/sql";
import driver from "k6/x/sql/driver/postgres";
import { check } from "k6";
import { randomIntBetween } from "https://jslib.k6.io/k6-utils/1.2.0/index.js";

const db = sql.open(driver, "postgres://postgres:postgres@localhost:5432/quickpizza_db?sslmode=disable");

export const options = {
  scenarios: {
    // Read: random pizza lookup
    get_pizza: {
      executor: "constant-arrival-rate",
      duration: "15s",
      rate: 10,
      timeUnit: "1s",
      preAllocatedVUs: 10,
      exec: "getPizza",
    },
    // Write: insert a rating for a random seeded pizza
    insert_rating: {
      executor: "constant-arrival-rate",
      duration: "15s",
      rate: 10,
      timeUnit: "1s",
      preAllocatedVUs: 10,
      exec: "insertRating",
    },
  },
};

// Seeded pizza IDs: 1–3
const PIZZA_IDS = [1, 2, 3];

export function setup() {
  const rows = db.query("SELECT COALESCE(MAX(id), 0) AS max_id FROM ratings;");
  return { maxRatingIdBefore: [...rows][0].max_id };
}

export function teardown({ maxRatingIdBefore }) {
  db.exec(`DELETE FROM ratings WHERE id > ${maxRatingIdBefore} AND user_id = 1 AND pizza_id IN (1, 2, 3)`);
  db.close();
}

export function getPizza() {
  const id = PIZZA_IDS[randomIntBetween(0, PIZZA_IDS.length - 1)];
  // Join that mirrors what the Catalog service fetches
  const rows = db.query(`
    SELECT p.id, p.name, d.name AS dough, p.tool,
           i.name AS ingredient, i.calories_per_slice
    FROM pizzas p
    JOIN doughs d ON d.id = p.dough_id
    JOIN pizza_to_ingredients pti ON pti.pizza_id = p.id
    JOIN ingredients i ON i.id = pti.ingredient_id
    WHERE p.id = $1;
  `, id);
  check([...rows], { "pizza with ingredients": (r) => r.length > 0 });
}

export function insertRating() {
  const pizzaId = PIZZA_IDS[randomIntBetween(0, PIZZA_IDS.length - 1)];
  const stars = randomIntBetween(1, 5);
  db.exec(
    `INSERT INTO ratings (user_id, pizza_id, stars) VALUES (1, $1, $2);`,
    pizzaId, stars
  );
}
