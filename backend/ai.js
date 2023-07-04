const { makeRoute } = require("./util");
const { OpenAIClient } = require("@fern-api/openai");
require("dotenv").config();

const client = new OpenAIClient({
  token: process.env.OPENAI_API_KEY,
});

const aiRoutes = makeRoute("/ai", async (msg) => {
  const textChunk = await reply(msg);
  return textChunk;
});

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
      onFinish: () => {},
    }
  );
}

module.exports = { aiRoutes };
