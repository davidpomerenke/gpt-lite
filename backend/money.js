fs = require("fs");
path = require("path");
const { makeHttpRoute, accountPath } = require("./util");
const stripe = require("stripe")("sk_test_..."); // TODO: ???

const balanceRoute = makeHttpRoute("/balance", (msg) => {
  return updateAndGetBalance(msg.user);
});

const moneyRoutes = (app) => {
  balanceRoute(app);
};

const updateAndGetBalance = (user, change = 0) => {
  fn = accountPath(user, "balance.txt");
  if (change !== 0) fs.appendFileSync(fn, change + "\n");
  const changes = fs
    .readFileSync(fn, "utf8")
    .split("\n")
    .map((s) => Number(s));
  const balance = changes.reduce((a, b) => a + b, 0);
  return balance;
};

module.exports = { moneyRoutes, updateAndGetBalance };
