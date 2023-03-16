import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
    vus: 10,
    duration: '30s'
};

export default function () {
    let restrictions = {
        "maxCaloriesPerSlice": 500,
        "mustBeVegetarian": true,
        "excludedIngredients": ["pepperoni"],
        "excludedTools": ["pizza cutter"],
        "maxNumberOfToppings": 3,
        "minNumberOfToppings": 2
    }
    let res = http.post('http://localhost:3333/api/pizza', JSON.stringify(restrictions));
    console.log(res.body);
    sleep(1);
}