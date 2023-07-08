const { createHash } = require("crypto");
require("dotenv").config({ path: path.resolve(__dirname, "./../.env") });

const makeRoute = (route, reply) => {
  const routeFn = (app) => {
    app.ws(route, function (ws, req) {
      ws.on("message", async function (msg) {
        try {
          msg = JSON.parse(msg);
          const replyMsg = await reply(msg);
          ws.send(JSON.stringify(replyMsg));
        } catch (err) {
          console.log(err);
        }
      });
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

module.exports = { makeRoute, accountPath, hash };
