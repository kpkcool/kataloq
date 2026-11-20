/**
 * Shared input patterns. Kept in one place so config, routes and the enquiry
 * schema all apply the same rules.
 */

/** Product IDs are opaque strings in our contract; this keeps them URL- and log-safe. */
export const PRODUCT_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/** Category IDs are lower-case slugs. */
export const CATEGORY_ID_PATTERN = /^[a-z0-9-]{1,64}$/;

/**
 * Pragmatic email check: one "@", no whitespace, a dot in the domain.
 * Deliberately not RFC 5322-complete; the mail server is the final judge.
 * Line breaks are rejected by `\s`, which also prevents email header injection.
 */
export const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const EMAIL_MAX_LENGTH = 254;

/** True if the value contains a CR or LF (header-injection guard). */
export function containsLineBreak(value: string): boolean {
  return /[\r\n]/.test(value);
}
