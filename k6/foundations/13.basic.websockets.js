import { sleep } from 'k6';
import { WebSocket } from 'k6/experimental/websockets';
import { setInterval } from 'k6/experimental/timers';
import { Counter } from "k6/metrics";

let BASE_URL = __ENV.BASE_URL || 'http://localhost:3333';

BASE_URL = BASE_URL.replace("https://", "wss://");
BASE_URL = BASE_URL.replace("http://", "ws://");

export const options = {
  scenarios: {
    receiver: {
      exec: "receiver",
      executor: "ramping-vus",
      executor: 'shared-iterations',
      iterations: 1,
      maxDuration: '1m',
    },
    sender: {
      exec: "sender",
      executor: 'shared-iterations',
      iterations: 20,
      vus: 10,

      // delay the start to get the receiver ready
      startTime: '2s',
    },

  }
};

// send two WS messages
export function sender() {
    const ws = new WebSocket(`${BASE_URL}/ws`);
    ws.addEventListener('open', () => {
        ws.send(JSON.stringify({ user: `VU ${__VU}`, msg: "order_pizza" }));
        sleep(0.2);
        ws.send(JSON.stringify({ user: `VU ${__VU}`, msg: "pizza_status?" }));
        sleep(0.1);
        ws.close();
    });
}

export function receiver () {

  // Close the WS connection to end the iteration once the number of expected messages is received.

  // Be aware that a local counter (`messageCounter`) is valid here because only one `receiver` iteration runs.
  let messageCounter = 0;
  const totalExpectedMessages = 20*2; // 20 iterations * 2 messages per iteration

  const ws = new WebSocket(`${BASE_URL}/ws`);
  ws.addEventListener('open', () => {
    ws.addEventListener('message', (e) => {
      const msg = JSON.parse(e.data);
      console.log(`VU ${__VU} received: ${msg.user} msg: ${msg.msg}`);
      messageCounter++;
      if (messageCounter === totalExpectedMessages) {
        ws.close();
      }
    });
  });
}