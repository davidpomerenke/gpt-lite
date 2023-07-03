path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "./../.env") });
var nodemailer = require("nodemailer");

const useLoginRoutess = (app) => {
  app.ws("/login", function (ws, req) {
    ws.on("message", async function (msg) {
      textChunk = await reply(JSON.parse(msg), ws);
    });
  });
};

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,
  port: 465,
  secure: true,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendEmail = async (baseUrl, emailAddress, code) => {
  const url = `${baseUrl}?login-code=${code}`;
  const text = `Copy ${url} into your browser to login.`;
  const html = `<p>Got to <a href="${url}">${url}</a> to login.</p>`;
  const info = await transporter.sendMail({
    from: ` "Alliterative AI" <${process.env.EMAIL_USER}>`,
    to: emailAddress,
    subject: "Login to ChatGPT Lite",
    text: text,
    html: html,
  });
};
