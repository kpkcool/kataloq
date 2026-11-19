import { describe, expect, it } from 'vitest';
import { buildEnquiryEmail } from '../../../src/providers/email/enquiryEmailTemplate.js';
import { makeProduct, mensClothing } from '../../support/products.js';

const product = makeProduct({
  id: '1',
  title: 'Fjallraven Backpack',
  category: mensClothing,
  price: { amount: 109.95, currency: 'USD' },
});

const base = {
  enquiryId: 'enq-123',
  receivedAt: new Date('2026-11-19T10:00:00.000Z'),
  product,
  from: 'Kataloq <no-reply@kataloq.test>',
  to: 'sales@kataloq.test',
};

describe('buildEnquiryEmail', () => {
  it('addresses the sales inbox and sets Reply-To to the customer', () => {
    const email = buildEnquiryEmail({ ...base, enquiry: { productId: '1', name: 'Jane', email: 'jane@example.com' } });

    expect(email.to).toBe('sales@kataloq.test');
    expect(email.from).toBe('Kataloq <no-reply@kataloq.test>');
    expect(email.replyTo).toBe('jane@example.com');
    expect(email.subject).toBe('New enquiry: Fjallraven Backpack');
  });

  it('includes the product and every customer field in the body', () => {
    const email = buildEnquiryEmail({
      ...base,
      enquiry: { productId: '1', name: 'Jane', email: 'jane@example.com', phone: '0400 000 000', message: 'Blue?\nThanks' },
    });

    for (const expected of [
      'Enquiry ID: enq-123',
      'Received:   2026-11-19T10:00:00.000Z',
      'ID:       1',
      'Title:    Fjallraven Backpack',
      "Category: Men's Clothing",
      'Price:    USD 109.95',
      'Name:     Jane',
      'Email:    jane@example.com',
      'Phone:    0400 000 000',
      'Blue?\nThanks',
    ]) {
      expect(email.text).toContain(expected);
    }
  });

  it('shows "(not provided)" for missing optional fields', () => {
    const email = buildEnquiryEmail({ ...base, enquiry: { productId: '1', name: 'Jane', email: 'jane@example.com' } });

    expect(email.text).toContain('Phone:    (not provided)');
    expect(email.text).toContain('MESSAGE\n(not provided)');
  });

  it('keeps the subject on one line and truncates very long titles', () => {
    const email = buildEnquiryEmail({
      ...base,
      product: { ...product, title: `Line one\r\nBcc: x@y.z ${'z'.repeat(200)}` },
      enquiry: { productId: '1', name: 'Jane', email: 'jane@example.com' },
    });

    expect(email.subject).not.toMatch(/[\r\n]/);
    expect(email.subject.length).toBeLessThanOrEqual('New enquiry: '.length + 120);
    expect(email.subject.endsWith('…')).toBe(true);
  });
});
