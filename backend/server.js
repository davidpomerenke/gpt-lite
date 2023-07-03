var express = require("express");
var app = express();
var expressWs = require("express-ws")(app);
const { useMoneyRoutes } = require("./money");
const { reply } = require("./ai");

app.use(express.static("../frontend/static"));

app.ws("/", function (ws, req) {
  ws.on("message", async function (msg) {
    textChunk = await reply(JSON.parse(msg), ws);
  });
});

useMoneyRoutes(app);

const PORT = process.env.PORT || 3000;
app.listen(PORT);
console.log(`Server is running on http://localhost:${PORT}`);
