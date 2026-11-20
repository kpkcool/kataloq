import { AppError } from '../domain/errors.js';

/** HTTP-level errors. They live here, not in the domain, because they're about the transport. */

export class UnsupportedMediaTypeError extends AppError {
  readonly status = 415;
  readonly code = 'UNSUPPORTED_MEDIA_TYPE';

  constructor() {
    super('Send the request body as JSON (Content-Type: application/json).');
  }
}

export class RateLimitedError extends AppError {
  readonly status = 429;
  readonly code = 'RATE_LIMITED';

  constructor() {
    super('Too many enquiries. Please wait a minute and try again.');
  }
}
