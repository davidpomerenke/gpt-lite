require("dotenv").config();
const { WebSocketServer } = require("ws");
const express = require("express");
const { OpenAIClient } = require("@fern-api/openai");

const client = new OpenAIClient({
  token: process.env.OPENAI_API_KEY,
});

const PORT = process.env.PORT || 3000;
const WS_PORT = process.env.WS_PORT || 3001;
const sockserver = new WebSocketServer({ port: WS_PORT });

console.log(`Websocket server started on port ${WS_PORT}`);

sockserver.on("connection", (ws) => {
  console.log("New client connected!");
  ws.on("close", () => console.log("Client has disconnected!"));
  ws.on("message", (data) => reply(JSON.parse(data.toString()), ws));
  ws.onerror = () => console.log("websocket error");
});

const app = express();
app.use(express.static("static"));
app.listen(PORT, () =>
  console.log(`Web server started on http://localhost:${PORT}`)
);
if (process.argv.includes("--open")) {
  import("open").then((open) => open.default(`http://localhost:${PORT}`));
}

async function reply(chatMessages, ws) {
  await client.chat.createCompletion(
    {
      model: "gpt-4",
      messages: chatMessages,
      temperature: 0,
      maxTokens: 2048,
      stream: true,
    },
    (data) => {
      const textChunk = data.choices[0].delta.content;
      if (textChunk) ws.send(textChunk);
    },
    {
      onError: (error) => {
        console.log("Received error", error);
      },
      onFinish: () => {
        console.log("Finished!");
      },
    }
  );
}
