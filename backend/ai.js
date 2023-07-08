const { OpenAIClient } = require("@fern-api/openai");
require("dotenv").config();

const client = new OpenAIClient({
  token: process.env.OPENAI_API_KEY,
});

const aiRoutes = (app) => {
  app.ws("/ai", function (ws, req) {
    ws.on("message", (msg) => {
      try {
        const chatMessages = JSON.parse(msg);
        reply(chatMessages, ws);
      } catch (err) {
        console.log(err);
      }
    });
  });
};

const reply = (chatMessages, ws) => {
  const params = {
    model: "gpt-4",
    messages: chatMessages,
    temperature: 0,
    maxTokens: 2048,
    stream: true,
  };

  client.chat.createCompletion(
    params,
    (data) => {
      const textChunk = data.choices[0].delta.content;
      if (textChunk) ws.send(JSON.stringify(textChunk));
    },
    {
      onError: (e) => console.warn(e),
      onFinish: () => console.log("finished"),
    }
  );
};

module.exports = { aiRoutes };
