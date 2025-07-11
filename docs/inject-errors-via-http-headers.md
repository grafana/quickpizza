## Injecting Errors from Client via Headers

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