path = require("path");
fs = require("fs");
const nodemailer = require("nodemailer");
const { accountPath, makeHttpRoute, hash } = require("./util");
const { updateAndGetBalance } = require("./money");

const emailRequestRoute = makeHttpRoute("/request-email", async (msg) => {
  const baseUrl = process.env.BASE_URL;
  const emailAddress = msg.email;
  const userId = hash(emailAddress);
  const code = generateAndSaveCode(userId);
  const success = await sendEmail(baseUrl, emailAddress, code);
  return success;
});

const loginRoute = makeHttpRoute("/login", async (msg) => {
  const { email, code } = msg;
  const id = hash(email);
  const correctCode = fs.readFileSync(accountPath(id, "code.txt"), "utf8");
  if (code === correctCode) return { balance: await updateAndGetBalance(id) };
  else {
    console.warn(`Code mismatch: ${email} ${code}`);
    return { balance: null };
  }
});

const accountRoutes = (app) => {
  emailRequestRoute(app);
  loginRoute(app);
};

const generateAndSaveCode = (id) => {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let code = "";
  for (let i = 0; i < 20; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  fs.writeFile(accountPath(id, "code.txt"), code, (err) => {
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

const sendEmail = async (baseUrl, emailAddress, code) => {
  const url = `${baseUrl}?email=${emailAddress}&code=${code}`;
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
    console.warn(err);
    return false;
  }
  return true;
};

module.exports = { accountRoutes };
