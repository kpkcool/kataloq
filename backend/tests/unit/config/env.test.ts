import { describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../../../src/config/env.js';

function expectConfigError(env: NodeJS.ProcessEnv, variable: string): void {
  let caught: unknown;
  try {
    loadConfig(env);
  } catch (error) {
    caught = error;
  }
  expect(caught).toBeInstanceOf(ConfigError);
  expect((caught as ConfigError).message).toContain(variable);
}

describe('loadConfig', () => {
  it('applies documented defaults when nothing is set', () => {
    const config = loadConfig({});

    expect(config).toEqual({
      port: 3000,
      logLevel: 'info',
      fakeStore: { baseUrl: 'https://fakestoreapi.com', timeoutMs: 5000 },
      productCache: { ttlSeconds: 60 },
      catalogue: { featuredProductIds: ['1', '5', '9', '14', '18'], categoryTopRatedCount: 3 },
      smtp: { host: 'localhost', port: 1025, secure: false, user: undefined, pass: undefined },
      email: { from: 'Kataloq <no-reply@kataloq.local>', salesInbox: 'sales@kataloq.local' },
      enquiryRateLimitPerMinute: 5,
    });
  });

  it('reads overrides from the environment', () => {
    const config = loadConfig({
      PORT: '8080',
      LOG_LEVEL: 'debug',
      FAKE_STORE_BASE_URL: 'https://example.test/api',
      UPSTREAM_TIMEOUT_MS: '2500',
      PRODUCT_CACHE_TTL_SECONDS: '0',
      FEATURED_PRODUCT_IDS: ' 2, 3 ,4,6,7 ',
      CATEGORY_TOP_RATED_COUNT: '5',
      SMTP_HOST: 'mailpit',
      SMTP_PORT: '2525',
      SMTP_SECURE: 'true',
      SMTP_USER: 'user',
      SMTP_PASS: 'secret',
      SALES_INBOX_EMAIL: 'team@example.com',
      ENQUIRY_RATE_LIMIT_PER_MINUTE: '20',
    });

    expect(config.port).toBe(8080);
    expect(config.logLevel).toBe('debug');
    expect(config.fakeStore).toEqual({ baseUrl: 'https://example.test/api', timeoutMs: 2500 });
    expect(config.productCache.ttlSeconds).toBe(0);
    expect(config.catalogue).toEqual({ featuredProductIds: ['2', '3', '4', '6', '7'], categoryTopRatedCount: 5 });
    expect(config.smtp).toEqual({ host: 'mailpit', port: 2525, secure: true, user: 'user', pass: 'secret' });
    expect(config.email.salesInbox).toBe('team@example.com');
    expect(config.enquiryRateLimitPerMinute).toBe(20);
  });

  it('treats empty strings as "not set" so defaults apply', () => {
    const config = loadConfig({ PORT: '', SMTP_USER: '', FEATURED_PRODUCT_IDS: '   ' });

    expect(config.port).toBe(3000);
    expect(config.smtp.user).toBeUndefined();
    expect(config.catalogue.featuredProductIds).toHaveLength(5);
  });

  describe('FEATURED_PRODUCT_IDS', () => {
    it('rejects fewer than five IDs', () => expectConfigError({ FEATURED_PRODUCT_IDS: '1,2,3,4' }, 'FEATURED_PRODUCT_IDS'));
    it('rejects more than five IDs', () => expectConfigError({ FEATURED_PRODUCT_IDS: '1,2,3,4,5,6' }, 'FEATURED_PRODUCT_IDS'));
    it('rejects duplicates', () => expectConfigError({ FEATURED_PRODUCT_IDS: '1,2,3,4,4' }, 'FEATURED_PRODUCT_IDS'));
    it('rejects invalid characters', () => expectConfigError({ FEATURED_PRODUCT_IDS: '1,2,3,4,../5' }, 'FEATURED_PRODUCT_IDS'));
    it('rejects an empty entry', () => expectConfigError({ FEATURED_PRODUCT_IDS: '1,2,,4,5' }, 'FEATURED_PRODUCT_IDS'));
  });

  it.each([
    ['PORT', 'abc'],
    ['PORT', '70000'],
    ['UPSTREAM_TIMEOUT_MS', '50'],
    ['PRODUCT_CACHE_TTL_SECONDS', '-1'],
    ['CATEGORY_TOP_RATED_COUNT', '0'],
    ['CATEGORY_TOP_RATED_COUNT', '21'],
    ['SMTP_SECURE', 'yes'],
    ['SALES_INBOX_EMAIL', 'not-an-email'],
    ['FAKE_STORE_BASE_URL', 'ftp://example.com'],
    ['LOG_LEVEL', 'verbose'],
  ])('rejects invalid %s=%s', (variable, value) => {
    expectConfigError({ [variable]: value }, variable);
  });

  it('rejects a From address containing a line break (header injection)', () => {
    expectConfigError({ EMAIL_FROM: 'Kataloq <a@b.c>\r\nBcc: x@y.z' }, 'EMAIL_FROM');
  });
});
