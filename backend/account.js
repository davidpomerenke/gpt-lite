path = require("path");
fs = require("fs");
const nodemailer = require("nodemailer");
const { accountPath, makeHttpRoute, hash } = require("./util");
const { updateAndGetBalance } = require("./money");

const emailRequestRoute = makeHttpRoute("/request-email", async (msg) => {
  const baseUrl = process.env.BASE_URL;
  const emailAddress = msg.email;
  const userId = hash(emailAddress);
  const code = generateAndSaveCode(emailAddress);
  const success = await sendEmail(baseUrl, emailAddress, userId, code);
  return success;
});

const loginRoute = makeHttpRoute("/login", async (msg) => {
  const { email, id, code } = msg;
  if (hash(email) !== id) return { balance: null };
  const correctCode = fs.readFileSync(accountPath(email, "code.txt"), "utf8");
  if (code === correctCode) return { balance: updateAndGetBalance(id) };
  else return { balance: null };
});

const accountRoutes = (app) => {
  emailRequestRoute(app);
  loginRoute(app);
};

const generateAndSaveCode = (email) => {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let code = "";
  for (let i = 0; i < 32; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  fs.writeFile(accountPath(email, "code.txt"), code, (err) => {
    if (err) throw err;
  });
  return code;
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

const sendEmail = async (baseUrl, emailAddress, id, code) => {
  const url = `${baseUrl}?email=${emailAddress}&id=${id}&code=${code}`;
  const text = `Copy ${url} into your browser to login.`;
  const html = `<p>Go to <a href="${url}">${url}</a> to login.</p>`;
  const mail = {
    from: `"Alliterative AI" <${process.env.EMAIL_USER}>`,
    to: emailAddress,
    subject: "Login to ChatGPT Lite",
    text: text,
    html: html,
  };
  try {
    await transporter.sendMail(mail);
  } catch (err) {
    console.log(err.message);
    return false;
  }
  return true;
};

module.exports = { accountRoutes };
