import { describe, expect, it } from 'vitest';
import { enquirySchema } from '../../../src/domain/enquiry.js';

const valid = { productId: '1', name: 'Jane Citizen', email: 'jane@example.com' };

function fieldErrors(input: unknown): Record<string, string> {
  const result = enquirySchema.safeParse(input);
  if (result.success) return {};
  return Object.fromEntries(result.error.issues.map((issue) => [issue.path.join('.'), issue.message]));
}

describe('enquirySchema', () => {
  it('accepts name + email only (phone and message are optional)', () => {
    expect(enquirySchema.parse(valid)).toEqual(valid);
  });

  it('accepts all fields and trims whitespace', () => {
    const parsed = enquirySchema.parse({
      productId: '1',
      name: '  Jane Citizen ',
      email: ' jane@example.com ',
      phone: ' +61 (0)400-000-000 ',
      message: '  Is this available in blue?\nThanks!  ',
    });

    expect(parsed).toEqual({
      productId: '1',
      name: 'Jane Citizen',
      email: 'jane@example.com',
      phone: '+61 (0)400-000-000',
      message: 'Is this available in blue?\nThanks!',
    });
  });

  it.each([[''], ['   '], [null]])('treats a blank optional field (%j) as not provided', (blank) => {
    const parsed = enquirySchema.parse({ ...valid, phone: blank, message: blank });
    expect(parsed.phone).toBeUndefined();
    expect(parsed.message).toBeUndefined();
  });

  it('strips unknown fields', () => {
    expect(enquirySchema.parse({ ...valid, isAdmin: true })).toEqual(valid);
  });

  it('reports every missing required field', () => {
    expect(fieldErrors({})).toEqual({
      productId: 'A product is required.',
      name: 'Enter your name.',
      email: 'Enter your email address.',
    });
  });

  it.each([
    ['too short', 'J', 'Name must be at least 2 characters.'],
    ['too long', 'x'.repeat(101), 'Name can be at most 100 characters.'],
    ['a line break', 'Jane\r\nBcc: spam@example.com', 'Name contains invalid characters.'],
    ['a control character', 'Jane\u0007', 'Name contains invalid characters.'],
  ])('rejects a name with %s', (_label, name, message) => {
    expect(fieldErrors({ ...valid, name })).toEqual({ name: message });
  });

  it.each([
    'not-an-email',
    'jane@',
    '@example.com',
    'jane@example',
    'jane doe@example.com',
    'jane@example.com\r\nBcc: spam@example.com',
    `${'a'.repeat(250)}@example.com`,
  ])('rejects email %j', (email) => {
    expect(Object.keys(fieldErrors({ ...valid, email }))).toEqual(['email']);
  });

  it.each(['+61 400 000 000', '(02) 9999-9999', '0400000000', '123456'])('accepts phone %j', (phone) => {
    expect(enquirySchema.parse({ ...valid, phone }).phone).toBe(phone);
  });

  it.each([
    ['letters', '0400 ABC 000', 'Phone number can contain digits, spaces, +, -, ( and ) only.'],
    ['too few digits', '12345', 'Phone number must have 6–15 digits.'],
    ['too many digits', '1234567890123456', 'Phone number must have 6–15 digits.'],
    ['a line break', '0400\n000000', 'Phone number can contain digits, spaces, +, -, ( and ) only.'],
  ])('rejects a phone number with %s', (_label, phone, message) => {
    expect(fieldErrors({ ...valid, phone })).toEqual({ phone: message });
  });

  it('allows line breaks and tabs in the message but rejects other control characters', () => {
    expect(enquirySchema.parse({ ...valid, message: 'Line 1\nLine 2\tTabbed' }).message).toBe('Line 1\nLine 2\tTabbed');
    expect(fieldErrors({ ...valid, message: 'Hi\u0000there' })).toEqual({ message: 'Message contains invalid characters.' });
  });

  it('rejects a message over 1000 characters', () => {
    expect(fieldErrors({ ...valid, message: 'x'.repeat(1001) })).toEqual({
      message: 'Message can be at most 1000 characters.',
    });
  });

  it('rejects a non-string field instead of coercing it', () => {
    expect(Object.keys(fieldErrors({ ...valid, name: 12345 }))).toEqual(['name']);
  });

  it('rejects an invalid product id', () => {
    expect(fieldErrors({ ...valid, productId: '../1' })).toEqual({ productId: 'Invalid product ID.' });
  });
});
