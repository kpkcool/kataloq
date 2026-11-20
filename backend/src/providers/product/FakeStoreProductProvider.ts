import type { Category, CategoryId, Product, ProductId } from '../../domain/types.js';
import { UpstreamBadResponseError, UpstreamTimeoutError, UpstreamUnavailableError } from '../../domain/errors.js';
import type { Logger } from '../../lib/logger.js';
import type { ProductProvider } from './ProductProvider.js';
import { fakeStoreCategoryNamesSchema, fakeStoreProductSchema } from './fakeStoreSchemas.js';
import { toCategory, toProduct } from './fakeStoreMapper.js';

export interface FakeStoreProductProviderOptions {
  readonly baseUrl: string;
  readonly timeoutMs: number;
  readonly userAgent: string;
  readonly logger: Logger;
  /** Injectable for tests; defaults to the global `fetch`. */
  readonly fetch?: typeof fetch;
}

/** Fake Store product IDs are positive integers. Anything else cannot exist there. */
const FAKE_STORE_ID_PATTERN = /^[1-9]\d{0,9}$/;

/** Sentinel for "the upstream says this resource does not exist". */
const NOT_FOUND = Symbol('not-found');

/**
 * Adapter: Fake Store API → ProductProvider.
 *
 * Responsibilities: HTTP calls with a timeout, translating transport failures into
 * domain errors, validating every payload, and mapping vendor shapes to domain types.
 */
export class FakeStoreProductProvider implements ProductProvider {
  private readonly baseUrl: string;
  private readonly fetchFn: typeof fetch;

  constructor(private readonly options: FakeStoreProductProviderOptions) {
    this.baseUrl = options.baseUrl.replace(/\/+$/, '');
    this.fetchFn = options.fetch ?? fetch;
  }

  async listProducts(): Promise<Product[]> {
    const body = await this.getJson('/products');
    return this.parseProductList(body, '/products');
  }

  async getProduct(id: ProductId): Promise<Product | null> {
    if (!FAKE_STORE_ID_PATTERN.test(id)) return null;

    const path = `/products/${id}`;
    const body = await this.getJson(path);
    // Fake Store quirk: an unknown id returns HTTP 200 with an empty body (verified), so
    // both "empty body" and "null" mean not found.
    if (body === NOT_FOUND || body === null) return null;

    const parsed = fakeStoreProductSchema.safeParse(body);
    if (!parsed.success) throw this.badResponse(path, parsed.error.issues[0]?.path.join('.'));
    return toProduct(parsed.data);
  }

  async listCategories(): Promise<Category[]> {
    const path = '/products/categories';
    const body = await this.getJson(path);
    const parsed = fakeStoreCategoryNamesSchema.safeParse(body === NOT_FOUND ? undefined : body);
    if (!parsed.success) throw this.badResponse(path, parsed.error.issues[0]?.path.join('.'));

    const categories = new Map<CategoryId, Category>();
    for (const rawName of parsed.data) {
      const category = toCategory(rawName);
      if (category.id !== '' && !categories.has(category.id)) categories.set(category.id, category);
    }
    return [...categories.values()];
  }

  /**
   * Filters the full product list rather than calling `/products/category/{name}`:
   * one request instead of two (no slug → raw-name lookup), no encoding of names like
   * "men's clothing", and fine for Fake Store's ~20 products. A provider for a large
   * catalogue would query by category instead; the interface allows that.
   */
  async listProductsByCategory(categoryId: CategoryId): Promise<Product[]> {
    const products = await this.listProducts();
    return products.filter((product) => product.category.id === categoryId);
  }

  /** Lists tolerate individual bad items (skipped + logged) so one bad record can't take down the catalogue. */
  private parseProductList(body: unknown, path: string): Product[] {
    if (!Array.isArray(body)) throw this.badResponse(path, 'expected an array');

    const products: Product[] = [];
    body.forEach((item, index) => {
      const parsed = fakeStoreProductSchema.safeParse(item);
      if (parsed.success) {
        products.push(toProduct(parsed.data));
      } else {
        this.options.logger.warn('Skipping invalid product from Fake Store', {
          path,
          index,
          issue: parsed.error.issues[0]?.path.join('.'),
        });
      }
    });
    return products;
  }

  /** GET + JSON parse. Resolves to NOT_FOUND for 404 or an empty body. */
  private async getJson(path: string): Promise<unknown> {
    const url = `${this.baseUrl}${path}`;
    const { logger } = this.options;

    let response: Response;
    let text: string;
    try {
      response = await this.fetchFn(url, {
        method: 'GET',
        headers: { accept: 'application/json', 'user-agent': this.options.userAgent },
        signal: AbortSignal.timeout(this.options.timeoutMs),
      });
      text = await response.text();
    } catch (error) {
      if (isTimeout(error)) {
        logger.warn('Fake Store request timed out', { path, timeoutMs: this.options.timeoutMs });
        throw new UpstreamTimeoutError({ cause: error });
      }
      logger.warn('Fake Store request failed', { path, err: toError(error) });
      throw new UpstreamUnavailableError({ cause: error });
    }

    if (response.headers.get('cf-mitigated') === 'challenge') {
      // Fake Store's Cloudflare protection challenged this request. We surface it, never bypass it (AD-16).
      logger.warn('Fake Store returned a Cloudflare challenge; product data unavailable', {
        path,
        status: response.status,
      });
      throw new UpstreamUnavailableError({ cause: new Error(`Cloudflare challenge (HTTP ${response.status})`) });
    }

    if (response.status === 404) return NOT_FOUND;

    if (!response.ok) {
      logger.warn('Fake Store returned an error status', { path, status: response.status });
      throw new UpstreamUnavailableError({ cause: new Error(`Fake Store HTTP ${response.status}`) });
    }

    if (text.trim() === '') return NOT_FOUND;

    try {
      return JSON.parse(text) as unknown;
    } catch (error) {
      throw this.badResponse(path, 'body is not JSON', error);
    }
  }

  private badResponse(path: string, detail: string | undefined, cause?: unknown): UpstreamBadResponseError {
    this.options.logger.warn('Fake Store returned an unexpected response', { path, detail });
    return new UpstreamBadResponseError({ cause: cause ?? new Error(`Unexpected response from ${path}: ${detail}`) });
  }
}

function isTimeout(error: unknown): boolean {
  return error instanceof Error && (error.name === 'TimeoutError' || (error.cause as Error | undefined)?.name === 'TimeoutError');
}

function toError(value: unknown): Error {
  return value instanceof Error ? value : new Error(String(value));
}
