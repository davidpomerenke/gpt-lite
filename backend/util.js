const { createHash } = require("crypto");

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

fs.mkdirSync("accounts/sessions", { recursive: true });
const accountPath = (email, fn) => {
  folder = "accounts/" + hash(email);
  fs.mkdirSync(folder, { recursive: true });
  return folder + "/" + fn;
};

const hash = (s) => createHash("sha256").update(s).digest("hex");

module.exports = { makeRoute, accountPath };
