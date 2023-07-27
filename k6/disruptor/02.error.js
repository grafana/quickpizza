import http from "k6/http";
import {check, sleep} from "k6";
import {ServiceDisruptor} from "k6/x/disruptor";

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

const scenarios = {
    disrupt: {
        executor: "shared-iterations",
        iterations: 1,
        exec: "disrupt",
    },
    load: {
        executor: "constant-vus",
        vus: 5,
        duration: "30s",
        startTime: "5s",
    },
};

if (__ENV.DISABLE_DISRUPT) {
    delete scenarios["disrupt"];
}

export const options = {
    scenarios: scenarios,
};

export function disrupt(data) {
    const disruptor = new ServiceDisruptor("quickpizza-catalog", "default");
    const targets = disruptor.targets();
    if (targets.length === 0) {
        throw new Error("expected list to have one target");
    }

    disruptor.injectHTTPFaults({errorRate: 0.1, errorCode: 503}, "40s");
}

export default function () {
    const restrictions = {
        "maxCaloriesPerSlice": 500,
        "mustBeVegetarian": false,
        "excludedIngredients": ["pepperoni"],
        "excludedTools": ["knife"],
        "maxNumberOfToppings": 6,
        "minNumberOfToppings": 2
    }

    let res = http.post(`${BASE_URL}/api/pizza`, JSON.stringify(restrictions), {
        headers: {
            "Content-Type": "application/json",
            "X-User-ID": 23423,
        },
    });
    check(res, {"status is 200": (res) => res.status === 200});

    sleep(1);
}
