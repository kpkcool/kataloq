import type { Product } from '../../domain/types.js';
import type { EnquiryInput } from '../../domain/enquiry.js';
import type { EmailMessage } from './EmailProvider.js';

export interface EnquiryEmailInput {
  readonly enquiryId: string;
  readonly receivedAt: Date;
  readonly product: Product;
  readonly enquiry: EnquiryInput;
  readonly from: string;
  readonly to: string;
}

const SUBJECT_TITLE_MAX = 120;

/**
 * Builds the plain-text email sent to the sales inbox.
 * Plain text only (no HTML), and the subject is built from the product title with
 * line breaks removed, so neither customer input nor upstream data can add headers.
 */
export function buildEnquiryEmail(input: EnquiryEmailInput): EmailMessage {
  const { product, enquiry } = input;
  const notProvided = '(not provided)';

  const text = [
    'New product enquiry received via Kataloq.',
    '',
    `Enquiry ID: ${input.enquiryId}`,
    `Received:   ${input.receivedAt.toISOString()}`,
    '',
    'PRODUCT',
    `  ID:       ${product.id}`,
    `  Title:    ${singleLine(product.title)}`,
    `  Category: ${product.category.name}`,
    `  Price:    ${product.price.currency} ${product.price.amount.toFixed(2)}`,
    '',
    'CUSTOMER',
    `  Name:     ${enquiry.name}`,
    `  Email:    ${enquiry.email}`,
    `  Phone:    ${enquiry.phone ?? notProvided}`,
    '',
    'MESSAGE',
    enquiry.message ?? notProvided,
    '',
    '— Reply to this email to respond to the customer directly.',
  ].join('\n');

  return {
    from: input.from,
    to: input.to,
    replyTo: enquiry.email,
    subject: `New enquiry: ${truncate(singleLine(product.title), SUBJECT_TITLE_MAX)}`,
    text,
  };
}

function singleLine(value: string): string {
  return value.replace(/[\r\n]+/g, ' ').trim();
}

function truncate(value: string, max: number): string {
  return value.length <= max ? value : `${value.slice(0, max - 1)}…`;
}
