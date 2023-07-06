fs = require("fs");
path = require("path");
const { makeRoute, accountPath } = require("./util");
const express = require("express");
const stripe = require("stripe")("sk_test_..."); // TODO: ???
require("dotenv").config({ path: path.resolve(__dirname, "./../.env") });

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
        fs.writeFileSync(`accounts/sessions/${data.id}.txt`, amount);
      }
      res.send(); // Return a 200 response to acknowledge receipt of the event
    } catch (err) {
      res.status(400).send(`Webhook Error: ${err.message}`);
      console.log(err.message);
      return;
    }
  });
};

const checkoutCompletionRoute = makeRoute("/checkout-complete", (msg) => {
  amount = fs.readFileSync(
    `accounts/sessions/${msg.checkoutSessionId}.txt`,
    "utf8"
  );
  return updateAndGetBalance(msg.email);
});

const balanceRoute = makeRoute("/balance", (msg) => {
  return updateAndGetBalance(msg.email);
});

const moneyRoutes = (app) => {
  stripeEndpointRoute(app);
  checkoutCompletionRoute(app);
  balanceRoute(app);
};

const updateAndGetBalance = (email, change = 0) => {
  fn = accountPath(email, "balance.txt");
  if (change !== 0) fs.appendFileSync(fn, change + "\n");
  const changes = fs
    .readFileSync(fn, "utf8")
    .split("\n")
    .map((s) => Number(s));
  const balance = changes.reduce((a, b) => a + b, 0);
  return balance;
};

module.exports = { moneyRoutes };
