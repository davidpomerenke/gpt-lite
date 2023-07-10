fs = require("fs");
path = require("path");
const { get } = require("http");
const { makeHttpRoute, accountPath } = require("./util");
const stripe = require("stripe")(process.env.STRIPE_API_KEY);

const balanceRoute = makeHttpRoute("/balance", (msg) => {
  return updateAndGetBalance(msg.user);
});

const moneyRoutes = (app) => {
  balanceRoute(app);
};

const updateAndGetBalance = async (user, change = 0) => {
  fn = accountPath(user, "balance.txt");
  if (change !== 0) fs.appendFileSync(fn, change + "\n");
  const changes = fs
    .readFileSync(fn, "utf8")
    .split("\n")
    .map((s) => Number(s));
  let balance = changes.reduce((a, b) => a + b, 0);
  balance += await getPayments(user);
  return balance;
};

const getPayments = async (id) => {
  const sessions = await stripe.checkout.sessions.list();
  return sessions.data
    .filter((a) => a.client_reference_id === id)
    .map((a) => a.amount_total / 100)
    .reduce((a, b) => a + b, 0);
};

module.exports = { moneyRoutes, updateAndGetBalance };
