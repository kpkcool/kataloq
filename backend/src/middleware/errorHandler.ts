import type { ErrorRequestHandler, RequestHandler } from 'express';
import { AppError, NotFoundError, ValidationError, type FieldError } from '../domain/errors.js';

export interface ApiErrorBody {
  error: {
    code: string;
    message: string;
    requestId: string;
    details?: readonly FieldError[];
  };
}

/** Unknown routes → 404 ROUTE_NOT_FOUND in the standard error shape. */
export const notFoundHandler: RequestHandler = (_req, _res, next) => {
  next(new NotFoundError('ROUTE_NOT_FOUND', 'The requested resource does not exist.'));
};

/**
 * The single place where errors become HTTP responses.
 *
 * - AppError → its own status, code and client-safe message.
 * - body-parser errors → 400 (invalid JSON) / 413 (too large) / 415.
 * - Anything else → 500 with a generic message. The real error is logged, never sent.
 */
export const errorHandler: ErrorRequestHandler = (error: unknown, _req, res, next) => {
  if (res.headersSent) {
    next(error);
    return;
  }

  const { requestId, logger } = res.locals;
  const send = (status: number, code: string, message: string, details?: readonly FieldError[]) => {
    const body: ApiErrorBody = { error: { code, message, requestId, ...(details ? { details } : {}) } };
    res.status(status).json(body);
  };

  if (error instanceof AppError) {
    if (error.status >= 500) {
      logger.warn('request failed', { code: error.code, status: error.status, err: error });
    }
    send(error.status, error.code, error.message, error instanceof ValidationError ? error.details : undefined);
    return;
  }

  if (isBodyParserError(error)) {
    switch (error.type) {
      case 'entity.too.large':
        send(413, 'PAYLOAD_TOO_LARGE', 'The request body is too large.');
        return;
      case 'entity.parse.failed':
        send(400, 'VALIDATION_ERROR', 'The request body must be valid JSON.');
        return;
      case 'encoding.unsupported':
      case 'charset.unsupported':
        send(415, 'UNSUPPORTED_MEDIA_TYPE', 'Unsupported request encoding.');
        return;
      default:
        break;
    }
  }

  logger.error('unhandled error', { err: error instanceof Error ? error : new Error(String(error)) });
  send(500, 'INTERNAL_ERROR', 'Something went wrong. Please try again.');
};

function isBodyParserError(error: unknown): error is { type: string; status: number } {
  return typeof error === 'object' && error !== null && typeof (error as { type?: unknown }).type === 'string';
}
