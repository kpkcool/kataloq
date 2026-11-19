import { randomUUID } from 'node:crypto';
import type { RequestHandler } from 'express';
import type { Logger } from '../lib/logger.js';

declare global {
  namespace Express {
    interface Locals {
      /** Correlates a client report, the error body and server log lines. */
      requestId: string;
      /** Logger with `requestId` already attached. */
      logger: Logger;
    }
  }
}

/** An incoming X-Request-Id is reused only if it looks safe (no log injection). */
const INCOMING_REQUEST_ID = /^[A-Za-z0-9._-]{8,64}$/;

/**
 * Gives every request an ID (echoed in the `X-Request-Id` header and in error bodies)
 * and a request-scoped logger, then logs one line when the response finishes.
 *
 * Only method, path (without query string), status and duration are logged:
 * never bodies, query strings or personal data.
 */
export function requestContext(logger: Logger): RequestHandler {
  return (req, res, next) => {
    const incoming = req.get('x-request-id');
    const requestId = incoming && INCOMING_REQUEST_ID.test(incoming) ? incoming : randomUUID();

    res.locals.requestId = requestId;
    res.locals.logger = logger.child({ requestId });
    res.setHeader('X-Request-Id', requestId);

    // originalUrl is never rewritten by mounted routers (req.path can be); drop the query string.
    const path = req.originalUrl.split('?')[0] ?? req.originalUrl;
    const startedAt = process.hrtime.bigint();
    res.on('finish', () => {
      const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
      res.locals.logger.info('request completed', {
        method: req.method,
        path,
        status: res.statusCode,
        durationMs: Math.round(durationMs * 10) / 10,
      });
    });

    next();
  };
}
