import { describe, expect, it, vi } from 'vitest';
import { SmtpEmailProvider, type MailTransport } from '../../../src/providers/email/SmtpEmailProvider.js';
import { EmailDeliveryError } from '../../../src/domain/errors.js';
import { silentLogger } from '../../../src/lib/logger.js';

const message = {
  from: 'Kataloq <no-reply@kataloq.test>',
  to: 'sales@kataloq.test',
  replyTo: 'jane@example.com',
  subject: 'New enquiry: Backpack',
  text: 'Body',
};

function providerWith(sendMail: MailTransport['sendMail']) {
  const transport = { sendMail: vi.fn(sendMail) };
  return { provider: new SmtpEmailProvider(transport, silentLogger), transport };
}

describe('SmtpEmailProvider', () => {
  it('passes the message to the transport and returns its message id', async () => {
    const { provider, transport } = providerWith(async () => ({ messageId: '<abc@mailpit>', rejected: [] }));

    await expect(provider.send(message)).resolves.toEqual({ messageId: '<abc@mailpit>' });
    expect(transport.sendMail).toHaveBeenCalledWith(message);
  });

  it('omits Reply-To when none is given', async () => {
    const { provider, transport } = providerWith(async () => ({ messageId: '<abc@mailpit>' }));
    const { replyTo: _omit, ...withoutReplyTo } = message;

    await provider.send(withoutReplyTo);

    expect(transport.sendMail).toHaveBeenCalledWith(withoutReplyTo);
  });

  it('throws EmailDeliveryError when the transport fails (e.g. SMTP server down)', async () => {
    const { provider } = providerWith(async () => {
      throw Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:1025'), { code: 'ESOCKET' });
    });

    await expect(provider.send(message)).rejects.toBeInstanceOf(EmailDeliveryError);
  });

  it('throws EmailDeliveryError when the server rejects the recipient', async () => {
    const { provider } = providerWith(async () => ({ messageId: '<abc@mailpit>', rejected: ['sales@kataloq.test'] }));

    await expect(provider.send(message)).rejects.toBeInstanceOf(EmailDeliveryError);
  });
});
