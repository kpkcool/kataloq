import type { AppConfig } from './config/env.js';
import type { Logger } from './lib/logger.js';
import type { ProductProvider } from './providers/product/ProductProvider.js';
import { FakeStoreProductProvider } from './providers/product/FakeStoreProductProvider.js';
import { CachingProductProvider } from './providers/product/CachingProductProvider.js';
import { CatalogueService } from './services/CatalogueService.js';
import { EnquiryService } from './services/EnquiryService.js';
import { SmtpEmailProvider } from './providers/email/SmtpEmailProvider.js';
import { createSmtpTransport } from './providers/email/smtpTransport.js';
import type { AppDependencies } from './app.js';
import { SERVICE_NAME, SERVICE_VERSION } from './version.js';

/**
 * Composition root: the ONLY place that knows which concrete adapters are used.
 * Replacing the product data source or email vendor means changing this file
 * (plus the new adapter), and nothing else.
 */
export function createContainer(config: AppConfig, logger: Logger): AppDependencies {
  let productProvider: ProductProvider = new FakeStoreProductProvider({
    baseUrl: config.fakeStore.baseUrl,
    timeoutMs: config.fakeStore.timeoutMs,
    userAgent: `${SERVICE_NAME}/${SERVICE_VERSION}`,
    logger: logger.child({ component: 'FakeStoreProductProvider' }),
  });

  if (config.productCache.ttlSeconds > 0) {
    productProvider = new CachingProductProvider(productProvider, { ttlMs: config.productCache.ttlSeconds * 1000 });
  }

  const catalogueService = new CatalogueService(productProvider, {
    featuredProductIds: config.catalogue.featuredProductIds,
    categoryTopRatedCount: config.catalogue.categoryTopRatedCount,
    logger: logger.child({ component: 'CatalogueService' }),
  });

  const emailProvider = new SmtpEmailProvider(
    createSmtpTransport(config.smtp),
    logger.child({ component: 'SmtpEmailProvider' }),
  );

  const enquiryService = new EnquiryService(productProvider, emailProvider, {
    fromEmail: config.email.from,
    salesInboxEmail: config.email.salesInbox,
    logger: logger.child({ component: 'EnquiryService' }),
  });

  return {
    catalogueService,
    enquiryService,
    logger,
    enquiryRateLimitPerMinute: config.enquiryRateLimitPerMinute,
  };
}
