# Injecting delays and errors 

QuickPizza supports two methods for injecting delays and errors to simulate various failure scenarios and performance issues during testing and demos.

## Using Environment variables

You can inject delays to endpoints and assets using environment variables. 

This is useful for testing scenarios where you want to simulate slow responses across multiple endpoints. 

```shell
export QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST=1000
```
The delay values should be specified in **milliseconds**.

The following environment variables are supported: 

- **QUICKPIZZA_DELAY_COPY**: Adds delay to all copy-related endpoints
     - **QUICKPIZZA_DELAY_COPY_API_QUOTES**: Adds delay specifically to the quotes API endpoint
     - **QUICKPIZZA_DELAY_COPY_API_NAMES**: Adds delay specifically to the names API endpoint  
     - **QUICKPIZZA_DELAY_COPY_API_ADJECTIVES**: Adds delay specifically to the adjectives API endpoint

- **QUICKPIZZA_DELAY_RECOMMENDATIONS**: Adds delay to all recommendation-related endpoints
     - **QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_GET**: Adds delay specifically to the GET pizza recommendations endpoint
     - **QUICKPIZZA_DELAY_RECOMMENDATIONS_API_PIZZA_POST**: Adds delay specifically to the POST pizza recommendations endpoint

- **QUICKPIZZA_DELAY_FRONTEND_CSS_ASSETS**: Adds delay when serving CSS assets
- **QUICKPIZZA_DELAY_FRONTEND_PNG_ASSETS**: Adds delay when serving PNG image assets

- **QUICKPIZZA_FAIL_RATE_RECOMMENDATIONS_API_PIZZA_POST**: Set to a number to fail `<number>%` of Pizza POST requests randomly.

## Using HTTP Headers

You can introduce errors from the client side using custom headers. Below is a list of the currently supported error headers:

- **x-error-record-recommendation**: Triggers an error when recording a recommendation. The header value should be the error message.
- **x-error-record-recommendation-percentage**: Specifies the percentage chance of an error occurring when recording a recommendation, if x-error-record-recommendation is also included. The header value should be a number between 0 and 100.
- **x-delay-record-recommendation**: Introduces a delay when recording a recommendation. The header value should specify the delay duration and unit. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h", "d", "w", "y".
- **x-delay-record-recommendation-percentage**: Specifies the percentage chance of a delay occurring when recording a recommendation, if x-delay-record-recommendation is also included. The header value should be a number between 0 and 100.
- **x-error-get-ingredients**: Triggers an error when retrieving ingredients. The header value should be the error message.
- **x-error-get-ingredients-percentage**: Specifies the percentage chance of an error occurring when retrieving ingredients, if x-error-get-ingredients is also included. The header value should be a number between 0 and 100.
- **x-delay-get-ingredients**: Introduces a delay when retrieving ingredients. The header value should specify the delay duration and unit. Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h", "d", "w", "y".
- **x-delay-get-ingredients-percentage**: Specifies the percentage chance of a delay occurring when retrieving ingredients, if x-delay-get-ingredients is also included. The header value should be a number between 0 and 100.

Example of header usage:

```shell
curl -X POST http://localhost:3333/api/pizza \
     -H "Content-Type: application/json" \
     -H "Authorization: abcdef0123456789" \
     -H "x-error-record-recommendation: internal-error" \
     -H "x-error-record-recommendation-percentage: 20" \
     -d '{}'
```