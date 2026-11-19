import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { EmailDeliveryError, UpstreamUnavailableError } from '../../src/domain/errors.js';
import { TEST_SALES_INBOX, buildTestApp } from '../support/app.js';
import { makeProduct } from '../support/products.js';

const products = [makeProduct({ id: '1', title: 'Backpack' })];
const validEnquiry = {
  productId: '1',
  name: 'Jane Citizen',
  email: 'jane@example.com',
  phone: '+61 400 000 000',
  message: 'Is this available in blue?',
};

function setup(options: { enquiryRateLimitPerMinute?: number } = {}) {
  return buildTestApp({ products, ...options });
}

describe('POST /api/v1/enquiries', () => {
  it('returns 202 with an enquiry id after the email is accepted, and sends exactly one email', async () => {
    const { app, email } = setup();

    const response = await request(app).post('/api/v1/enquiries').send(validEnquiry);

    expect(response.status).toBe(202);
    expect(response.body).toEqual({ enquiryId: expect.any(String), status: 'sent' });
    expect(response.headers['cache-control']).toBe('no-store');
    expect(email.sent).toHaveLength(1);
    expect(email.sent[0]?.to).toBe(TEST_SALES_INBOX);
    expect(email.sent[0]?.replyTo).toBe('jane@example.com');
    expect(email.sent[0]?.text).toContain(`Enquiry ID: ${response.body.enquiryId}`);
    expect(email.sent[0]?.text).toContain('Backpack');
  });

  it('accepts an enquiry with only the required fields', async () => {
    const { app, email } = setup();

    const response = await request(app)
      .post('/api/v1/enquiries')
      .send({ productId: '1', name: 'Jane', email: 'jane@example.com', phone: '', message: '' });

    expect(response.status).toBe(202);
    expect(email.sent[0]?.text).toContain('Phone:    (not provided)');
  });

  it('returns 400 with one detail per invalid field, and sends nothing', async () => {
    const { app, email } = setup();

    const response = await request(app)
      .post('/api/v1/enquiries')
      .send({ productId: '1', name: 'J', email: 'nope', phone: 'call me' });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(response.body.error.details.map((detail: { field: string }) => detail.field).sort()).toEqual([
      'email',
      'name',
      'phone',
    ]);
    expect(email.sent).toHaveLength(0);
  });

  it('returns 400 for an empty body', async () => {
    const { app } = setup();

    const response = await request(app).post('/api/v1/enquiries').send({});

    expect(response.status).toBe(400);
    expect(response.body.error.details.map((detail: { field: string }) => detail.field).sort()).toEqual([
      'email',
      'name',
      'productId',
    ]);
  });

  it('rejects an email header-injection attempt', async () => {
    const { app, email } = setup();

    const response = await request(app)
      .post('/api/v1/enquiries')
      .send({ ...validEnquiry, email: 'jane@example.com\r\nBcc: victim@example.com' });

    expect(response.status).toBe(400);
    expect(email.sent).toHaveLength(0);
  });

  it('returns 404 PRODUCT_NOT_FOUND for an unknown product, and sends nothing', async () => {
    const { app, email } = setup();

    const response = await request(app).post('/api/v1/enquiries').send({ ...validEnquiry, productId: '999' });

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('PRODUCT_NOT_FOUND');
    expect(email.sent).toHaveLength(0);
  });

  it('returns 502 EMAIL_DELIVERY_FAILED when the email provider fails (never 2xx)', async () => {
    const { app, email } = setup();
    email.failWith(new EmailDeliveryError());

    const response = await request(app).post('/api/v1/enquiries').send(validEnquiry);

    expect(response.status).toBe(502);
    expect(response.body).toEqual({
      error: {
        code: 'EMAIL_DELIVERY_FAILED',
        message: 'We could not send your enquiry right now. Please try again.',
        requestId: expect.any(String),
      },
    });
  });

  it('returns 502 when the product source is down, and sends nothing', async () => {
    const { app, provider, email } = setup();
    provider.failWith(new UpstreamUnavailableError());

    const response = await request(app).post('/api/v1/enquiries').send(validEnquiry);

    expect(response.status).toBe(502);
    expect(response.body.error.code).toBe('UPSTREAM_UNAVAILABLE');
    expect(email.sent).toHaveLength(0);
  });

  it('returns 415 for a non-JSON body', async () => {
    const { app, email } = setup();

    const response = await request(app)
      .post('/api/v1/enquiries')
      .set('Content-Type', 'application/x-www-form-urlencoded')
      .send('productId=1&name=Jane&email=jane%40example.com');

    expect(response.status).toBe(415);
    expect(response.body.error.code).toBe('UNSUPPORTED_MEDIA_TYPE');
    expect(email.sent).toHaveLength(0);
  });

  it('returns 413 for a body over 10 KB', async () => {
    const { app } = setup();

    const response = await request(app)
      .post('/api/v1/enquiries')
      .send({ ...validEnquiry, message: 'x'.repeat(11 * 1024) });

    expect(response.status).toBe(413);
  });

  it('returns 429 RATE_LIMITED once a client exceeds the per-minute limit', async () => {
    const { app, email } = setup({ enquiryRateLimitPerMinute: 2 });

    const statuses: number[] = [];
    let last: request.Response | undefined;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      last = await request(app).post('/api/v1/enquiries').send(validEnquiry);
      statuses.push(last.status);
    }

    expect(statuses).toEqual([202, 202, 429]);
    expect(last?.body.error.code).toBe('RATE_LIMITED');
    expect(last?.headers['retry-after']).toEqual(expect.any(String));
    expect(email.sent).toHaveLength(2);
  });

  it('does not rate-limit the catalogue endpoints', async () => {
    const { app } = setup({ enquiryRateLimitPerMinute: 1 });

    for (let attempt = 0; attempt < 3; attempt += 1) {
      const response = await request(app).get('/api/v1/products/1');
      expect(response.status).toBe(200);
    }
  });

  it('never writes personal data to the logs', async () => {
    const { app, logLines } = setup();

    await request(app).post('/api/v1/enquiries').send(validEnquiry);

    const logged = JSON.stringify(logLines);
    for (const personal of ['Jane', 'jane@example.com', '400 000 000', 'available in blue']) {
      expect(logged).not.toContain(personal);
    }
    expect(logLines).toContainEqual(expect.objectContaining({ msg: 'enquiry sent', productId: '1' }));
  });
});
