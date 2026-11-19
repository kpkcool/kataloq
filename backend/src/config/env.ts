import { z } from 'zod';
import type { LogLevel } from '../lib/logger.js';
import { EMAIL_MAX_LENGTH, EMAIL_PATTERN, PRODUCT_ID_PATTERN, containsLineBreak } from '../domain/validation.js';

/**
 * Typed application configuration, read from environment variables once at startup.
 * Invalid configuration fails fast with a readable message instead of failing at
 * the first request. See backend/.env.example for documentation of each variable.
 */
export interface AppConfig {
  readonly port: number;
  readonly logLevel: LogLevel;
  readonly fakeStore: {
    readonly baseUrl: string;
    readonly timeoutMs: number;
  };
  readonly productCache: {
    /** 0 disables the cache. */
    readonly ttlSeconds: number;
  };
  readonly catalogue: {
    /** Exactly 5 unique IDs, in display order. */
    readonly featuredProductIds: readonly string[];
    readonly categoryTopRatedCount: number;
  };
  readonly smtp: {
    readonly host: string;
    readonly port: number;
    readonly secure: boolean;
    readonly user: string | undefined;
    readonly pass: string | undefined;
  };
  readonly email: {
    readonly from: string;
    readonly salesInbox: string;
  };
  readonly enquiryRateLimitPerMinute: number;
}

export const FEATURED_PRODUCT_COUNT = 5;

export class ConfigError extends Error {
  constructor(readonly problems: readonly string[]) {
    super(`Invalid configuration:\n${problems.map((problem) => `  - ${problem}`).join('\n')}`);
    this.name = 'ConfigError';
  }
}

const integer = (min: number, max: number, fallback: number) =>
  z.coerce.number().int().min(min).max(max).default(fallback);

const booleanString = (fallback: boolean) =>
  z
    .enum(['true', 'false'], { message: 'must be "true" or "false"' })
    .default(fallback ? 'true' : 'false')
    .transform((value) => value === 'true');

const httpUrl = z.string().refine(
  (value) => {
    try {
      const url = new URL(value);
      return url.protocol === 'https:' || url.protocol === 'http:';
    } catch {
      return false;
    }
  },
  { message: 'must be an http(s) URL' },
);

const emailAddress = z
  .string()
  .max(EMAIL_MAX_LENGTH)
  .regex(EMAIL_PATTERN, { message: 'must be an email address' });

const featuredIds = z
  .string()
  .default('1,5,9,14,18')
  .transform((value) => value.split(',').map((id) => id.trim()))
  .refine((ids) => ids.length === FEATURED_PRODUCT_COUNT, {
    message: `must contain exactly ${FEATURED_PRODUCT_COUNT} comma-separated product IDs`,
  })
  .refine((ids) => ids.every((id) => PRODUCT_ID_PATTERN.test(id)), {
    message: 'contains an invalid product ID (allowed: letters, digits, "-" and "_")',
  })
  .refine((ids) => new Set(ids).size === ids.length, { message: 'must not contain duplicate product IDs' });

const envSchema = z.object({
  PORT: integer(1, 65535, 3000),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error', 'silent']).default('info'),

  FAKE_STORE_BASE_URL: httpUrl.default('https://fakestoreapi.com'),
  UPSTREAM_TIMEOUT_MS: integer(100, 30_000, 5_000),
  PRODUCT_CACHE_TTL_SECONDS: integer(0, 86_400, 60),

  FEATURED_PRODUCT_IDS: featuredIds,
  CATEGORY_TOP_RATED_COUNT: integer(1, 20, 3),

  SMTP_HOST: z.string().min(1).default('localhost'),
  SMTP_PORT: integer(1, 65535, 1025),
  SMTP_SECURE: booleanString(false),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  EMAIL_FROM: z
    .string()
    .min(1)
    .max(320)
    .refine((value) => !containsLineBreak(value), { message: 'must not contain line breaks' })
    .default('Kataloq <no-reply@kataloq.local>'),
  SALES_INBOX_EMAIL: emailAddress.default('sales@kataloq.local'),

  ENQUIRY_RATE_LIMIT_PER_MINUTE: integer(1, 1_000, 5),
});

/**
 * Parses configuration from an environment object (defaults to `process.env`).
 * Empty strings are treated as "not set", so `VAR=` in a .env file or `${VAR:-}`
 * in Docker Compose falls back to the default.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const cleaned: Record<string, string> = {};
  for (const [key, value] of Object.entries(env)) {
    if (value !== undefined && value.trim() !== '') cleaned[key] = value.trim();
  }

  const result = envSchema.safeParse(cleaned);
  if (!result.success) {
    throw new ConfigError(result.error.issues.map((issue) => `${issue.path.join('.') || 'env'}: ${issue.message}`));
  }

  const parsed = result.data;
  return {
    port: parsed.PORT,
    logLevel: parsed.LOG_LEVEL,
    fakeStore: { baseUrl: parsed.FAKE_STORE_BASE_URL, timeoutMs: parsed.UPSTREAM_TIMEOUT_MS },
    productCache: { ttlSeconds: parsed.PRODUCT_CACHE_TTL_SECONDS },
    catalogue: {
      featuredProductIds: parsed.FEATURED_PRODUCT_IDS,
      categoryTopRatedCount: parsed.CATEGORY_TOP_RATED_COUNT,
    },
    smtp: {
      host: parsed.SMTP_HOST,
      port: parsed.SMTP_PORT,
      secure: parsed.SMTP_SECURE,
      user: parsed.SMTP_USER,
      pass: parsed.SMTP_PASS,
    },
    email: { from: parsed.EMAIL_FROM, salesInbox: parsed.SALES_INBOX_EMAIL },
    enquiryRateLimitPerMinute: parsed.ENQUIRY_RATE_LIMIT_PER_MINUTE,
  };
}
