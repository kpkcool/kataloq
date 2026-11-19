import type { Category, CategoryId, Product, ProductId } from '../../domain/types.js';
import type { ProductProvider } from './ProductProvider.js';

export interface CachingProductProviderOptions {
  /** How long a successful result is reused, in milliseconds. */
  readonly ttlMs: number;
  /** Hard cap on cached keys; the oldest entry is evicted first. */
  readonly maxEntries?: number;
  /** Injectable clock (ms since epoch) so tests can move time without sleeping. */
  readonly now?: () => number;
}

interface CacheEntry {
  readonly promise: Promise<unknown>;
  /** `undefined` while the request is still in flight. */
  expiresAt: number | undefined;
}

const DEFAULT_MAX_ENTRIES = 500;

/**
 * Decorator that adds a short in-memory cache to ANY ProductProvider (D11 / AD-6).
 *
 * - Only successful results are cached; a rejected request is removed so the next call retries.
 * - Entries expire `ttlMs` after the request resolves.
 * - Concurrent misses for the same key share one upstream request ("single-flight"):
 *   the map stores the in-flight promise, not just the value.
 * - `null` ("product not found") is not cached, so requests for made-up IDs can't grow the cache.
 *
 * It implements the same interface as the provider it wraps, so services can't tell it is
 * there, and it can be removed or replaced (e.g. by a Redis-backed decorator) on its own.
 * The cache is per process: it is not shared between instances and is lost on restart.
 */
export class CachingProductProvider implements ProductProvider {
  private readonly entries = new Map<string, CacheEntry>();
  private readonly ttlMs: number;
  private readonly maxEntries: number;
  private readonly now: () => number;

  constructor(
    private readonly inner: ProductProvider,
    options: CachingProductProviderOptions,
  ) {
    this.ttlMs = options.ttlMs;
    this.maxEntries = options.maxEntries ?? DEFAULT_MAX_ENTRIES;
    this.now = options.now ?? Date.now;
  }

  listProducts(): Promise<Product[]> {
    return this.cached('products', () => this.inner.listProducts());
  }

  getProduct(id: ProductId): Promise<Product | null> {
    return this.cached(`product:${id}`, () => this.inner.getProduct(id), (product) => product !== null);
  }

  listCategories(): Promise<Category[]> {
    return this.cached('categories', () => this.inner.listCategories());
  }

  listProductsByCategory(categoryId: CategoryId): Promise<Product[]> {
    return this.cached(`category:${categoryId}`, () => this.inner.listProductsByCategory(categoryId));
  }

  private cached<T>(key: string, load: () => Promise<T>, shouldCache: (value: T) => boolean = () => true): Promise<T> {
    const existing = this.entries.get(key);
    if (existing && (existing.expiresAt === undefined || existing.expiresAt > this.now())) {
      // Fresh value or a request already in flight: share it.
      return existing.promise as Promise<T>;
    }
    if (existing) this.entries.delete(key);

    const isCurrent = (): boolean => this.entries.get(key) === entry;

    const promise = new Promise<T>((resolve) => resolve(load())).then(
      (value) => {
        if (isCurrent()) {
          if (shouldCache(value)) entry.expiresAt = this.now() + this.ttlMs;
          else this.entries.delete(key);
        }
        return value;
      },
      (error: unknown) => {
        if (isCurrent()) this.entries.delete(key);
        throw error;
      },
    );

    const entry: CacheEntry = { promise, expiresAt: undefined };
    this.evictIfFull();
    this.entries.set(key, entry);
    return promise;
  }

  private evictIfFull(): void {
    while (this.entries.size >= this.maxEntries) {
      const oldestKey = this.entries.keys().next().value;
      if (oldestKey === undefined) return;
      this.entries.delete(oldestKey);
    }
  }
}
