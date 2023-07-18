const { createHash } = require("crypto");
const express = require("express");
require("dotenv").config({ path: path.resolve(__dirname, "./../.env") });

const makeHttpRoute = (route, reply) => {
  const routeFn = (app) => {
    console.log("listening on", route);
    app.post(
      route,
      express.raw({ type: "application/json" }),
      async (req, res) => {
        try {
          res.send(await reply(req.body, req, res));
        } catch (err) {
          console.warn(err);
          res.status(400).send();
        }
      }
    );
  };
  return routeFn;
};

const accountPath = (user, fn) => {
  folder = "backend/accounts/" + user;
  fs.mkdirSync(folder, { recursive: true });
  const path = folder + "/" + fn;
  fs.closeSync(fs.openSync(path, "a"));
  return path;
};

const hash = (s) => createHash("sha256").update(s).digest("hex");

module.exports = { makeHttpRoute, accountPath, hash };
