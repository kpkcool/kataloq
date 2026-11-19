import { ConfigError, loadConfig, type AppConfig } from './config/env.js';
import { createLogger } from './lib/logger.js';
import { createApp } from './app.js';
import { createContainer } from './container.js';
import { SERVICE_NAME, SERVICE_VERSION } from './version.js';

/** Process entry point: config → container → HTTP server, plus process-level safety nets. */

let config: AppConfig;
try {
  config = loadConfig();
} catch (error) {
  // Fail fast with a readable message; the process manager / Compose shows it.
  console.error(error instanceof ConfigError ? error.message : error);
  process.exit(1);
}

const logger = createLogger({ level: config.logLevel, base: { service: SERVICE_NAME } });

// An unhandled rejection or exception leaves the process in an unknown state:
// log it and exit so the orchestrator restarts a clean instance.
process.on('unhandledRejection', (reason) => {
  logger.error('unhandled promise rejection; exiting', { err: reason instanceof Error ? reason : new Error(String(reason)) });
  process.exit(1);
});
process.on('uncaughtException', (error) => {
  logger.error('uncaught exception; exiting', { err: error });
  process.exit(1);
});

const app = createApp(createContainer(config, logger));

const server = app.listen(config.port, () => {
  logger.info('kataloq-api started', {
    version: SERVICE_VERSION,
    port: config.port,
    productSource: config.fakeStore.baseUrl,
    productCacheTtlSeconds: config.productCache.ttlSeconds,
    featuredProductIds: config.catalogue.featuredProductIds,
    categoryTopRatedCount: config.catalogue.categoryTopRatedCount,
    smtp: `${config.smtp.host}:${config.smtp.port}`,
    salesInbox: config.email.salesInbox,
  });
});

server.on('error', (error) => {
  logger.error('server failed to start', { err: error });
  process.exit(1);
});

// Graceful shutdown: stop accepting connections, let in-flight requests finish.
for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => {
    logger.info('shutting down', { signal });
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}
