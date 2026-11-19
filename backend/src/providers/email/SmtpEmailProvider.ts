import { EmailDeliveryError } from '../../domain/errors.js';
import type { Logger } from '../../lib/logger.js';
import type { EmailMessage, EmailProvider } from './EmailProvider.js';

/**
 * The slice of an SMTP client this adapter needs. nodemailer's Transporter satisfies it
 * (see smtpTransport.ts); tests pass a fake.
 */
export interface MailTransport {
  sendMail(message: {
    from: string;
    to: string;
    replyTo?: string;
    subject: string;
    text: string;
  }): Promise<{ messageId?: string; rejected?: readonly unknown[] }>;
}

/**
 * Adapter: SMTP → EmailProvider. Locally it talks to Mailpit; in production any SMTP
 * relay (including AWS SES's SMTP interface) works by configuration alone.
 */
export class SmtpEmailProvider implements EmailProvider {
  constructor(
    private readonly transport: MailTransport,
    private readonly logger: Logger,
  ) {}

  async send(message: EmailMessage): Promise<{ messageId: string }> {
    let info: Awaited<ReturnType<MailTransport['sendMail']>>;
    try {
      info = await this.transport.sendMail({
        from: message.from,
        to: message.to,
        ...(message.replyTo ? { replyTo: message.replyTo } : {}),
        subject: message.subject,
        text: message.text,
      });
    } catch (error) {
      // Connection refused, auth failure, timeout, 5xx from the server...: never success.
      this.logger.warn('SMTP send failed', { err: error instanceof Error ? error : new Error(String(error)) });
      throw new EmailDeliveryError({ cause: error });
    }

    if (info.rejected && info.rejected.length > 0) {
      this.logger.warn('SMTP server rejected the recipient', { rejectedCount: info.rejected.length });
      throw new EmailDeliveryError({ cause: new Error('Recipient rejected by SMTP server') });
    }

    return { messageId: info.messageId ?? 'unknown' };
  }
}
