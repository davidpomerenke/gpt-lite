fs = require("fs");
path = require("path");
const { makeHttpRoute, accountPath } = require("./util");
const stripe = require("stripe")(process.env.STRIPE_API_KEY);

const endpointSecret = process.env.STRIPE_ENDPOINT_SECRET;

const stripeEndpointRoute = makeHttpRoute("/stripe", (msg, req) => {
  const sig = req.headers["stripe-signature"];
  let event;
  event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  if (event.type === "checkout.session.completed") {
    const data = event.data.object;
    const amount = data.amount_subtotal / 100;
    console.log(data.client_reference_id, amount);
    updateAndGetBalance(data.client_reference_id, amount);
  }
  return; // Return a 200 response to acknowledge receipt of the event
});

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
  return changes.reduce((a, b) => a + b, 0);
};

module.exports = {
  moneyRoutes,
  stripeEndpointRoute,
  updateAndGetBalance,
};
