import { Client, StatusOK } from 'k6/net/grpc';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3334';

const client = new Client();
client.load(['definitions'], '../../../proto/quickpizza.proto');

export default () => {
  client.connect(BASE_URL, {
    plaintext: true
  });

  const data = { ingredients: ["Pepperoni", "Mozzarella"], dough: "Stuffed" };
  const response = client.invoke('quickpizza.GRPC/EvaluatePizza', data);

  check(response, {
    'status is OK': (r) => r && r.status === StatusOK,
  });

  console.log(JSON.stringify(response.message));

  client.close();
  sleep(1);
};
