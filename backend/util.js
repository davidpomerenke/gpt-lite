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

module.exports = { makeRoute };
