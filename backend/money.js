fs = require("fs");
const stripe = require("stripe")("sk_test_...");
const express = require("express");
require("dotenv").config();

const endpointSecret = process.env.STRIPE_ENDPOINT_SECRET;

const useMoneyRoutes = (app) => {
  app.post("/top-up", express.raw({ type: "application/json" }), (req, res) => {
    const sig = req.headers["stripe-signature"];
    let event;
    try {
      event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }
    switch (event.type) {
      case "checkout.session.completed":
        const data = event.data.object;
        updateAndGetBalance(data["amount_subtotal"]);
        break;
      default:
        break;
    }
    res.send(); // Return a 200 response to acknowledge receipt of the event
  });
};

const updateAndGetBalance = (change = 0) => {
  fn = "balance.txt";
  if (change !== 0) fs.appendFileSync(fn, change + "\n");
  const changes = fs
    .readFileSync(fn, "utf8")
    .split("\n")
    .map((s) => Number(s));
  const balance = changes.reduce((a, b) => a + b, 0);
  console.log("New balance: " + balance);
  return balance;
};

module.exports = {
  useMoneyRoutes,
};
