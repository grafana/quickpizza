import http from "k6/http";
import chai, {
  describe,
  expect,
} from "https://jslib.k6.io/k6chaijs/4.5.0.1/index.js";
chai.config.exitOnError = true;

const BASE_URL = __ENV.BASE_URL || "http://localhost:3333";

export const options = {
  vus: 1,
  iterations: 1,
};

function randomString(length) {
  let result = '';
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const charactersLength = characters.length;
  let counter = 0;
  while (counter < length) {
    result += characters.charAt(Math.floor(Math.random() * charactersLength));
    counter += 1;
  }
  return result;
}

function testCreateUserLogin() {
  let username = randomString(32);
  let password = randomString(32);

  describe("Create a user and log in", () => {
    let data = {username: username, password: password};
    var res = http.post(`${BASE_URL}/api/users`, JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
      }
    });

    expect(res.status, "response status").to.equal(201);

    res = http.post(`${BASE_URL}/api/users/token/login`, JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
      }
    });

    expect(res.status, "response status").to.equal(200);
    expect(res.json().token.length, "token").to.equal(16);
  });

  describe("Fail to log in", () => {
    // Invalid password
    var res = http.post(`${BASE_URL}/api/users/token/login`, JSON.stringify({
      username: username,
      password: "foo",
    }), {
      headers: {
        'Content-Type': 'application/json',
      }
    });

    expect(res.status, "response status").to.equal(401);
    expect(res).to.have.validJsonBody();

    // User does not exist
    res = http.post(`${BASE_URL}/api/users/token/login`, JSON.stringify({
      username: "foo",
      password: "foo",
    }), {
      headers: {
        'Content-Type': 'application/json',
      }
    });

    expect(res.status, "response status").to.equal(401);

    // Cannot log in as default user
    res = http.post(`${BASE_URL}/api/users/token/login`, JSON.stringify({
      username: "default",
      password: "",
    }), {
      headers: {
        'Content-Type': 'application/json',
      }
    });

    expect(res.status, "response status").to.equal(401);
  });
}

function testTokenValidation() {
  describe("Validate a token", () => {
    var res = http.post(`${BASE_URL}/api/users/token/authenticate`, {
      headers: {
        "X-Is-Internal": "1",
      }
    });

    expect(res.status, "response status").to.equal(401);

    res = http.post(`${BASE_URL}/api/users/token/authenticate`, {
      headers: {
        "Authorization": "token tooshort",
        "X-Is-Internal": "1",
      }
    });

    expect(res.status, "response status").to.equal(401);

    // A randomly-generated token with correct length of 16 will
    // yield the default user (id=1). See comment in routes/+page.svelte.
    res = http.post(`${BASE_URL}/api/users/token/authenticate`, null, {
      headers: {
        "Authorization": "token aaaaaaaaaaaaaaaa",
        "X-Is-Internal": "1",
      }
    });

    expect(res.status, "response status").to.equal(200);
    expect(res.json().id, "id").to.equal(1);
    expect(res.json().username, "username").to.equal("default");
  });
}

export default function() {
  testCreateUserLogin();
  testTokenValidation();
}
