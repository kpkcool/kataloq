import { z } from 'zod';
import { EMAIL_MAX_LENGTH, EMAIL_PATTERN, PRODUCT_ID_PATTERN } from './validation.js';

/**
 * Enquiry validation (D2). The backend is authoritative; the iOS app mirrors these
 * rules only to give earlier feedback.
 *
 *   productId  required  same pattern as the product path parameter
 *   name       required  2–100 chars after trimming, no line breaks or control characters
 *   email      required  ≤254 chars, one "@", no whitespace (so no header injection)
 *   phone      optional  digits, spaces, + - ( ) ; 6–15 digits
 *   message    optional  ≤1000 chars; line breaks allowed (it is only ever email body text)
 *
 * Blank optional fields ("" or spaces) mean "not provided", not "invalid".
 * Unknown fields are stripped, so newer clients don't break older servers.
 */

export const ENQUIRY_LIMITS = {
  nameMin: 2,
  nameMax: 100,
  phoneDigitsMin: 6,
  phoneDigitsMax: 15,
  messageMax: 1000,
} as const;

// Control characters (incl. CR/LF), except in the message where \n, \r and \t are allowed.
const CONTROL_CHARS = /[\u0000-\u001F\u007F]/;
const CONTROL_CHARS_EXCEPT_WHITESPACE = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/;
const PHONE_CHARS = /^\+?[0-9 ()-]+$/;

/** "" / "   " / null → undefined, other strings trimmed. Non-strings pass through to fail validation. */
const blankToUndefined = (value: unknown) => {
  if (value === null) return undefined;
  if (typeof value !== 'string') return value;
  const trimmed = value.trim();
  return trimmed === '' ? undefined : trimmed;
};

const requiredText = (fieldLabel: string) =>
  z.preprocess(blankToUndefined, z.string({ message: `Enter your ${fieldLabel}.` }));

export const enquirySchema = z.object({
  productId: z
    .string({ message: 'A product is required.' })
    .regex(PRODUCT_ID_PATTERN, { message: 'Invalid product ID.' }),

  name: requiredText('name')
    .pipe(
      z
        .string()
        .min(ENQUIRY_LIMITS.nameMin, { message: `Name must be at least ${ENQUIRY_LIMITS.nameMin} characters.` })
        .max(ENQUIRY_LIMITS.nameMax, { message: `Name can be at most ${ENQUIRY_LIMITS.nameMax} characters.` })
        .refine((value) => !CONTROL_CHARS.test(value), { message: 'Name contains invalid characters.' }),
    ),

  email: requiredText('email address')
    .pipe(
      z
        .string()
        .max(EMAIL_MAX_LENGTH, { message: 'Email address is too long.' })
        .regex(EMAIL_PATTERN, { message: 'Enter a valid email address.' }),
    ),

  phone: z
    .preprocess(
      blankToUndefined,
      z
        .string({ message: 'Enter a valid phone number.' })
        .regex(PHONE_CHARS, { message: 'Phone number can contain digits, spaces, +, -, ( and ) only.' })
        .refine(
          (value) => {
            const digits = value.replace(/\D/g, '').length;
            return digits >= ENQUIRY_LIMITS.phoneDigitsMin && digits <= ENQUIRY_LIMITS.phoneDigitsMax;
          },
          {
            message: `Phone number must have ${ENQUIRY_LIMITS.phoneDigitsMin}–${ENQUIRY_LIMITS.phoneDigitsMax} digits.`,
          },
        )
        .optional(),
    ),

  message: z
    .preprocess(
      blankToUndefined,
      z
        .string({ message: 'Message must be text.' })
        .max(ENQUIRY_LIMITS.messageMax, { message: `Message can be at most ${ENQUIRY_LIMITS.messageMax} characters.` })
        .refine((value) => !CONTROL_CHARS_EXCEPT_WHITESPACE.test(value), { message: 'Message contains invalid characters.' })
        .optional(),
    ),
});

export type EnquiryInput = z.output<typeof enquirySchema>;
