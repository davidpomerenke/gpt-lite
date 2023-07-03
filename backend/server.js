var express = require("express");
var app = express();
var expressWs = require("express-ws")(app);
const { useMoneyRoutes } = require("./money");
const { reply, useAiRoutes } = require("./ai");

app.use(express.static("../frontend/static"));

useAiRoutes(app);
useMoneyRoutes(app);

const PORT = process.env.PORT || 3000;
app.listen(PORT);
console.log(`Server is running on http://localhost:${PORT}`);
