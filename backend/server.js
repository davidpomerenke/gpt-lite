var express = require("express");
var app = express();
var expressWs = require("express-ws")(app);
const { accountRoutes } = require("./account");
const { moneyRoutes } = require("./money");
const { aiRoutes } = require("./ai");

app.use(express.static("../frontend/static"));

accountRoutes(app);
moneyRoutes(app);
aiRoutes(app);

const PORT = process.env.PORT || 3000;
app.listen(PORT);
console.log(`Server is running on http://localhost:${PORT}`);
