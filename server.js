require("dotenv").config();
const { WebSocketServer } = require("ws");

const { OpenAIClient } = require("@fern-api/openai");

const client = new OpenAIClient({
  token: process.env.OPENAI_API_KEY,
});

const PORT = process.env.PORT || 3001;
const sockserver = new WebSocketServer({ port: PORT });

console.log(`Websocket server started on port ${PORT}`);

sockserver.on("connection", (ws) => {
  console.log("New client connected!");
  ws.on("close", () => console.log("Client has disconnected!"));
  ws.on("message", (data) => reply(JSON.parse(data.toString()), ws));
  ws.onerror = () => console.log("websocket error");
});

async function reply(chatMessages, ws) {
  await client.chat.createCompletion(
    {
      model: "gpt-4",
      messages: chatMessages,
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
