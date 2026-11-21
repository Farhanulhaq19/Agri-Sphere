require('dotenv').config();
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
  connectionTimeout: 15000,
});

transporter.verify((err) => {
  if (err) console.error('Email setup problem:', err.message);
  else console.log('Email server ready');
});

async function sendVerificationEmail(to, code) {
  if (process.env.DEV_MODE === 'true') {
    console.log(`DEV MODE: code for ${to} is ${code}`);
    return { sent: false, devCode: code };
  }
  try {
    await transporter.sendMail({
      from: `"AgriSphere" <${process.env.EMAIL_USER}>`,
      to,
      subject: 'Your AgriSphere verification code',
      html: `<p>Your AgriSphere verification code is:</p><h2 style="letter-spacing:4px">${code}</h2><p>It expires in 10 minutes.</p>`,
    });
    return { sent: true };
  } catch (err) {
    console.error('Email send failed:', err.message);
    throw err;
  }
}

module.exports = { sendVerificationEmail };
