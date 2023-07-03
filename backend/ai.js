require("dotenv").config();
const { OpenAIClient } = require("@fern-api/openai");

const client = new OpenAIClient({
  token: process.env.OPENAI_API_KEY,
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
