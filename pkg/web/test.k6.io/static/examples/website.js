import http from "k6/http";
import { check, group, sleep } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";
import { randomIntBetween } from "https://jslib.k6.io/k6-utils/1.0.0/index.js";

// download the data file here: https://test.k6.io/static/examples/users.json
const loginData = JSON.parse(open("./users.json"));  

export let options = {
    stages: [
        { target: 10, duration: "5s" },
        { target: 10, duration: "20s" },
        { target: 0, duration: "5s" }
    ],
    thresholds: {
        "http_req_duration": ["p(95)<1000"],
        "http_req_duration{staticAsset:yes}": ["p(95)<500"],
        "check_failure_rate": ["rate<0.1"]
    }
};

// Custom metrics
// We instantiate them before our main function
let successfulLogins = new Counter("successful_logins");
let checkFailureRate = new Rate("check_failure_rate");
let timeToFirstByte = new Trend("time_to_first_byte", true);

// baseURL hosted the PHP website
const baseURL = "http://test.k6.io";

/* Main function
The main function is what the virtual users will loop over during test execution.
*/
export default function() {
    // We define our first group. Pages naturally fit a concept of a group
    // You may have other similar actions you wish to "group" together
    group("Front page", function() {
        let res = null;

	res = http.get(`${baseURL}/?ts=` + Math.round(randomIntBetween(1,2000)), { tags: { name: `${baseURL} Aggregated`}});

        let checkRes = check(res, {
            "Homepage body size is higher than 10000 bytes": (r) => r.body.length > 10000,
            "Homepage welcome header present": (r) => r.body.indexOf("Welcome to the k6.io demo site!") !== -1
        });

        // Record check failures
        checkFailureRate.add(!checkRes);

        // Record time to first byte and tag it with the URL to be able to filter the results in Insights
        timeToFirstByte.add(res.timings.waiting, { ttfbURL: res.url });

        // Load static assets
        group("Static assets", function() {
            let res = http.batch([
                ["GET", `${baseURL}/static/css/site.css`, {}, { tags: { staticAsset: "yes" } }],
                ["GET", `${baseURL}/static/js/prisms.js`, {}, { tags: { staticAsset: "yes" } }]
            ]);
            checkRes = check(res[0], {
                "did return the css style?": (r) => r.status === 200,
            });

            // Record check failures
            checkFailureRate.add(!checkRes);

            // Record time to first byte and tag it with the URL to be able to filter the results in Insights
            timeToFirstByte.add(res[0].timings.waiting, { ttfbURL: res[0].url, staticAsset: "yes" });
            timeToFirstByte.add(res[1].timings.waiting, { ttfbURL: res[1].url, staticAsset: "yes" });
        });

    });

    sleep(3);

    group("Login", function() {
        let res = http.get(`${baseURL}/my_messages.php`);
        let checkRes = check(res, {
            "Users should not be auth'd. Is unauthorized header present?": (r) => r.body.indexOf("Unauthorized") !== -1
        });
            
        //extracting the CSRF token from the response

        const vars = {};

        vars["csrftoken"] = res
            .html()
            .find("input[name=csrftoken]")
            .first()
            .attr("value");    

        // Record check failures
        checkFailureRate.add(!checkRes);

        let position = Math.floor(Math.random()*loginData.users.length);
        let credentials = loginData.users[position];

        res = http.post(`${baseURL}/login.php`, { login: credentials.username, password: credentials.password, redir: '1', csrftoken: `${vars["csrftoken"]}` });
        checkRes = check(res, {
	    "login status is 200": (r) => r.status === 200,
            "is logged in welcome header present": (r) => r.body.indexOf("Welcome, admin!") !== -1
        });

        // Record successful logins
        if (checkRes) {
            successfulLogins.add(1);
        }

        // Record check failures
        checkFailureRate.add(!checkRes, { page: "login" });

        // Record time to first byte and tag it with the URL to be able to filter the results in Insights
        timeToFirstByte.add(res.timings.waiting, { ttfbURL: res.url });

        sleep(1);
    });
}