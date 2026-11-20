import { createApp } from '../../src/app.js';
import { createLogger, type Logger } from '../../src/lib/logger.js';
import { CatalogueService } from '../../src/services/CatalogueService.js';
import { EnquiryService } from '../../src/services/EnquiryService.js';
import type { Product } from '../../src/domain/types.js';
import { InMemoryProductProvider } from './products.js';
import { FakeEmailProvider } from './email.js';

export interface TestAppOptions {
  readonly products: Product[];
  readonly featuredProductIds?: string[];
  readonly categoryTopRatedCount?: number;
  readonly enquiryRateLimitPerMinute?: number;
}

export const TEST_SALES_INBOX = 'sales@kataloq.test';
export const TEST_FROM = 'Kataloq <no-reply@kataloq.test>';

/** The real Express app wired to in-memory fakes, plus captured JSON log lines. */
export function buildTestApp(options: TestAppOptions) {
  const logLines: Record<string, unknown>[] = [];
  const logger: Logger = createLogger({
    level: 'debug',
    write: (line) => logLines.push(JSON.parse(line) as Record<string, unknown>),
  });

  const provider = new InMemoryProductProvider(options.products);
  const email = new FakeEmailProvider();

  const catalogueService = new CatalogueService(provider, {
    featuredProductIds: options.featuredProductIds ?? options.products.slice(0, 5).map((product) => product.id),
    categoryTopRatedCount: options.categoryTopRatedCount ?? 3,
    logger,
  });
  const enquiryService = new EnquiryService(provider, email, {
    fromEmail: TEST_FROM,
    salesInboxEmail: TEST_SALES_INBOX,
    logger,
  });

  const app = createApp({
    catalogueService,
    enquiryService,
    logger,
    enquiryRateLimitPerMinute: options.enquiryRateLimitPerMinute ?? 100,
  });
  return { app, provider, email, logLines };
}
