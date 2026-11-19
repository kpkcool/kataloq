/**
 * Application errors.
 *
 * Each error carries an HTTP status, a stable machine-readable `code` for clients,
 * and a message that is SAFE to show to a client. Anything internal (upstream
 * status codes, vendor messages, stack traces) goes in `cause` and is only logged.
 */

export interface FieldError {
  readonly field: string;
  readonly message: string;
}

export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'PRODUCT_NOT_FOUND'
  | 'CATEGORY_NOT_FOUND'
  | 'ROUTE_NOT_FOUND'
  | 'UPSTREAM_UNAVAILABLE'
  | 'UPSTREAM_BAD_RESPONSE'
  | 'UPSTREAM_TIMEOUT'
  | 'EMAIL_DELIVERY_FAILED';

export abstract class AppError extends Error {
  abstract readonly status: number;
  abstract readonly code: ErrorCode;

  constructor(message: string, options?: { cause?: unknown }) {
    super(message, options);
    this.name = new.target.name;
  }
}

export class ValidationError extends AppError {
  readonly status = 400;
  readonly code = 'VALIDATION_ERROR';
  readonly details: readonly FieldError[];

  constructor(details: readonly FieldError[], message = 'Some fields are invalid.') {
    super(message);
    this.details = details;
  }
}

export class NotFoundError extends AppError {
  readonly status = 404;
  readonly code: 'PRODUCT_NOT_FOUND' | 'CATEGORY_NOT_FOUND' | 'ROUTE_NOT_FOUND';

  constructor(code: NotFoundError['code'], message: string) {
    super(message);
    this.code = code;
  }
}

/** The product data source could not be reached or refused the request. */
export class UpstreamUnavailableError extends AppError {
  readonly status = 502;
  readonly code = 'UPSTREAM_UNAVAILABLE';

  constructor(options?: { cause?: unknown }) {
    super('Product data is temporarily unavailable. Please try again.', options);
  }
}

/** The product data source answered with something we could not understand. */
export class UpstreamBadResponseError extends AppError {
  readonly status = 502;
  readonly code = 'UPSTREAM_BAD_RESPONSE';

  constructor(options?: { cause?: unknown }) {
    super('Product data is temporarily unavailable. Please try again.', options);
  }
}

/** The product data source did not answer within the configured timeout. */
export class UpstreamTimeoutError extends AppError {
  readonly status = 504;
  readonly code = 'UPSTREAM_TIMEOUT';

  constructor(options?: { cause?: unknown }) {
    super('Product data is taking too long to load. Please try again.', options);
  }
}

/** The email provider did not accept the message. Never reported to the client as success. */
export class EmailDeliveryError extends AppError {
  readonly status = 502;
  readonly code = 'EMAIL_DELIVERY_FAILED';

  constructor(options?: { cause?: unknown }) {
    super('We could not send your enquiry right now. Please try again.', options);
  }
}
