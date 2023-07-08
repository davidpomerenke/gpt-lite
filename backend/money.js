fs = require("fs");
path = require("path");
const { makeRoute, accountPath } = require("./util");
const express = require("express");
const stripe = require("stripe")("sk_test_..."); // TODO: ???

const endpointSecret = process.env.STRIPE_ENDPOINT_SECRET;

const stripeEndpointRoute = (app) => {
  app.post("/top-up", express.raw({ type: "application/json" }), (req, res) => {
    try {
      const sig = req.headers["stripe-signature"];
      let event;
      event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
      if (event.type === "checkout.session.completed") {
        const data = event.data.object;
        const amount = data.amount_subtotal / 100;
        console.log(data);
        updateAndGetBalance(data.client_reference_id, amount);
      }
      res.send(); // Return a 200 response to acknowledge receipt of the event
    } catch (err) {
      res.status(400).send(`Webhook Error: ${err.message}`);
      console.log(err.message);
      return;
    }
  });
};

const balanceRoute = makeRoute("/balance", (msg) => {
  return updateAndGetBalance(msg.user);
});

const moneyRoutes = (app) => {
  stripeEndpointRoute(app);
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

module.exports = { moneyRoutes };
