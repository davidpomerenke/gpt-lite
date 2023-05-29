require("dotenv").config();
const { WebSocketServer } = require("ws");
const PORT = process.env.PORT || 3001;
const sockserver = new WebSocketServer({ port: PORT });
const { OpenAIClient } = require("@fern-api/openai");

const client = new OpenAIClient({
  token: process.env.OPENAI_API_KEY,
});

console.log(`Server started on port ${PORT} :)`);

sockserver.on("connection", (ws) => {
  console.log("New client connected!");
  ws.on("close", () => console.log("Client has disconnected!"));
  ws.on("message", (data) => reply(JSON.parse(data.toString()), ws));
  ws.onerror = () => console.log("websocket error");
});

async function reply(chatMessages, ws) {
  await client.chat.createCompletion(
    {
      model: "gpt-3.5-turbo",
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
