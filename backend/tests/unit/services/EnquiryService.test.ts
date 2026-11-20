import { describe, expect, it, vi } from 'vitest';
import { EnquiryService } from '../../../src/services/EnquiryService.js';
import { EmailDeliveryError, NotFoundError, UpstreamTimeoutError } from '../../../src/domain/errors.js';
import type { Logger } from '../../../src/lib/logger.js';
import { InMemoryProductProvider, makeProduct } from '../../support/products.js';
import { FakeEmailProvider } from '../../support/email.js';

const enquiry = {
  productId: '1',
  name: 'Jane Citizen',
  email: 'jane@example.com',
  phone: '0400 000 000',
  message: 'Is this in stock?',
};

function setup() {
  const provider = new InMemoryProductProvider([makeProduct({ id: '1', title: 'Backpack' })]);
  const email = new FakeEmailProvider();
  const logger = { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn(), child: vi.fn() };
  logger.child.mockReturnValue(logger);
  const service = new EnquiryService(provider, email, {
    fromEmail: 'Kataloq <no-reply@kataloq.test>',
    salesInboxEmail: 'sales@kataloq.test',
    logger: logger satisfies Logger,
    now: () => new Date('2026-11-19T10:00:00.000Z'),
    generateId: () => 'enq-1',
  });
  return { service, provider, email, logger };
}

describe('EnquiryService', () => {
  it('emails the sales inbox once and returns the enquiry id', async () => {
    const { service, email } = setup();

    await expect(service.submit(enquiry)).resolves.toEqual({ enquiryId: 'enq-1' });

    expect(email.sent).toHaveLength(1);
    expect(email.sent[0]).toEqual(
      expect.objectContaining({
        to: 'sales@kataloq.test',
        from: 'Kataloq <no-reply@kataloq.test>',
        replyTo: 'jane@example.com',
        subject: 'New enquiry: Backpack',
      }),
    );
    expect(email.sent[0]?.text).toContain('Enquiry ID: enq-1');
  });

  it('logs ids only, never personal data', async () => {
    const { service, logger } = setup();

    await service.submit(enquiry);

    expect(logger.info).toHaveBeenCalledWith('enquiry sent', { enquiryId: 'enq-1', productId: '1', messageId: expect.any(String) });
    const everythingLogged = JSON.stringify([logger.info.mock.calls, logger.warn.mock.calls, logger.error.mock.calls]);
    for (const personal of ['Jane', 'jane@example.com', '0400 000 000', 'in stock']) {
      expect(everythingLogged).not.toContain(personal);
    }
  });

  it('rejects an unknown product with PRODUCT_NOT_FOUND and sends nothing', async () => {
    const { service, email } = setup();

    const error = await service.submit({ ...enquiry, productId: '999' }).catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(NotFoundError);
    expect((error as NotFoundError).code).toBe('PRODUCT_NOT_FOUND');
    expect(email.sent).toHaveLength(0);
  });

  it('propagates an email provider failure as EmailDeliveryError (never success)', async () => {
    const { service, email, logger } = setup();
    email.failWith(new EmailDeliveryError());

    await expect(service.submit(enquiry)).rejects.toBeInstanceOf(EmailDeliveryError);
    expect(logger.info).not.toHaveBeenCalled();
  });

  it('wraps any other provider error in EmailDeliveryError', async () => {
    const { service, email } = setup();
    email.failWith(new Error('socket hang up'));

    const error = await service.submit(enquiry).catch((caught: unknown) => caught);

    expect(error).toBeInstanceOf(EmailDeliveryError);
    expect((error as EmailDeliveryError).message).not.toContain('socket');
  });

  it('propagates a product-source failure and sends nothing', async () => {
    const { service, provider, email } = setup();
    provider.failWith(new UpstreamTimeoutError());

    await expect(service.submit(enquiry)).rejects.toBeInstanceOf(UpstreamTimeoutError);
    expect(email.sent).toHaveLength(0);
  });
});
