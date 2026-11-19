import { rateLimit } from 'express-rate-limit';
import type { RequestHandler } from 'express';
import { RateLimitedError } from '../http/errors.js';

/**
 * Per-client-IP limit on enquiry submissions: a public form that sends email is an
 * obvious spam target. Over the limit → 429 RATE_LIMITED in the standard error shape,
 * with RateLimit / Retry-After headers.
 *
 * Limitations (documented): counts are in memory, so they reset on restart and are
 * not shared between instances (a shared store or API Gateway throttling would be
 * needed at scale). Behind Docker's port mapping every client shares the gateway IP,
 * so locally the limit is effectively global.
 */
export function enquiryRateLimiter(limitPerMinute: number): RequestHandler {
  return rateLimit({
    windowMs: 60_000,
    limit: limitPerMinute,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (_req, _res, next) => next(new RateLimitedError()),
  });
}
