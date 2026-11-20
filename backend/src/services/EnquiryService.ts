import { randomUUID } from 'node:crypto';
import { EmailDeliveryError, NotFoundError } from '../domain/errors.js';
import type { EnquiryInput } from '../domain/enquiry.js';
import type { Logger } from '../lib/logger.js';
import type { ProductProvider } from '../providers/product/ProductProvider.js';
import type { EmailProvider } from '../providers/email/EmailProvider.js';
import { buildEnquiryEmail } from '../providers/email/enquiryEmailTemplate.js';

export interface EnquiryServiceOptions {
  readonly fromEmail: string;
  readonly salesInboxEmail: string;
  readonly logger: Logger;
  readonly now?: () => Date;
  readonly generateId?: () => string;
}

export interface EnquiryReceipt {
  readonly enquiryId: string;
}

/**
 * Enquiry use case (FR-6/7/8): confirm the product exists, email the sales inbox,
 * and only then report success. Depends on interfaces, not on SMTP or Fake Store.
 * Enquiries are not stored (AS / "simplified"): the email is the record.
 */
export class EnquiryService {
  private readonly now: () => Date;
  private readonly generateId: () => string;

  constructor(
    private readonly products: ProductProvider,
    private readonly email: EmailProvider,
    private readonly options: EnquiryServiceOptions,
  ) {
    this.now = options.now ?? (() => new Date());
    this.generateId = options.generateId ?? randomUUID;
  }

  async submit(enquiry: EnquiryInput): Promise<EnquiryReceipt> {
    const product = await this.products.getProduct(enquiry.productId);
    if (!product) throw new NotFoundError('PRODUCT_NOT_FOUND', 'Product not found.');

    const enquiryId = this.generateId();
    const message = buildEnquiryEmail({
      enquiryId,
      receivedAt: this.now(),
      product,
      enquiry,
      from: this.options.fromEmail,
      to: this.options.salesInboxEmail,
    });

    let messageId: string;
    try {
      ({ messageId } = await this.email.send(message));
    } catch (error) {
      // Whatever the provider threw, the customer must be told it did NOT work.
      throw error instanceof EmailDeliveryError ? error : new EmailDeliveryError({ cause: error });
    }

    // IDs only: no name, email, phone or message in logs.
    this.options.logger.info('enquiry sent', { enquiryId, productId: product.id, messageId });
    return { enquiryId };
  }
}
