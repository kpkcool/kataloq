import nodemailer from 'nodemailer';
import type { AppConfig } from '../../config/env.js';
import type { MailTransport } from './SmtpEmailProvider.js';

/**
 * Builds the real nodemailer transport from config. Kept apart from SmtpEmailProvider
 * so the adapter's logic is testable without nodemailer.
 * Timeouts are short so a dead SMTP server fails the request quickly instead of hanging it.
 */
export function createSmtpTransport(smtp: AppConfig['smtp']): MailTransport {
  const transporter = nodemailer.createTransport({
    host: smtp.host,
    port: smtp.port,
    secure: smtp.secure,
    ...(smtp.user ? { auth: { user: smtp.user, pass: smtp.pass ?? '' } } : {}),
    connectionTimeout: 5_000,
    greetingTimeout: 5_000,
    socketTimeout: 10_000,
  });

  return {
    sendMail: (message) => transporter.sendMail(message),
  };
}
