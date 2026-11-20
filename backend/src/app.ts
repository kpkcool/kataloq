import express, { type Express } from 'express';
import type { Logger } from './lib/logger.js';
import type { CatalogueService } from './services/CatalogueService.js';
import type { EnquiryService } from './services/EnquiryService.js';
import { requestContext } from './middleware/requestContext.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { catalogueRoutes } from './routes/catalogueRoutes.js';
import { enquiryRoutes } from './routes/enquiryRoutes.js';
import { enquiryRateLimiter } from './middleware/rateLimiter.js';

export interface AppDependencies {
  readonly catalogueService: CatalogueService;
  readonly enquiryService: EnquiryService;
  readonly logger: Logger;
  readonly enquiryRateLimitPerMinute: number;
}

/** Request bodies above this size are rejected with 413. Enquiries are a few hundred bytes. */
export const MAX_BODY_SIZE = '10kb';

/**
 * Builds the Express app from already-constructed services.
 * Takes no config and creates no adapters, so tests can build the real app with fakes.
 */
export function createApp(deps: AppDependencies): Express {
  const app = express();

  app.disable('x-powered-by');
  app.use(requestContext(deps.logger));
  app.use((_req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    next();
  });
  app.use(express.json({ limit: MAX_BODY_SIZE }));

  // Health check for Docker Compose / load balancers. Never calls upstream.
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/api/v1', catalogueRoutes(deps.catalogueService));
  app.use('/api/v1', enquiryRoutes(deps.enquiryService, enquiryRateLimiter(deps.enquiryRateLimitPerMinute)));

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
