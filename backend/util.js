const { createHash } = require("crypto");
const express = require("express");
require("dotenv").config({ path: path.resolve(__dirname, "./../.env") });

const makeHttpRoute = (route, reply) => {
  const routeFn = (app) => {
    console.log("listening on", route);
    app.post(route, async (req, res) => {
      try {
        res.send(await reply(req.body));
      } catch (err) {
        console.warn(err);
        res.status(400).send();
      }
    });
  };
  return routeFn;
};

const accountPath = (user, fn) => {
  folder = "accounts/" + user;
  fs.mkdirSync(folder, { recursive: true });
  return folder + "/" + fn;
};

const hash = (s) => createHash("sha256").update(s).digest("hex");

module.exports = { makeHttpRoute, accountPath, hash };
