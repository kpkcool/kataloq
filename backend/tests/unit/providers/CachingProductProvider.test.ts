import { describe, expect, it, vi } from 'vitest';
import { CachingProductProvider } from '../../../src/providers/product/CachingProductProvider.js';
import type { ProductProvider } from '../../../src/providers/product/ProductProvider.js';
import type { Product } from '../../../src/domain/types.js';
import { UpstreamUnavailableError } from '../../../src/domain/errors.js';

const TTL_MS = 60_000;

function product(id: string): Product {
  return {
    id,
    title: `Product ${id}`,
    description: '',
    price: { amount: 1, currency: 'USD' },
    category: { id: 'electronics', name: 'Electronics' },
    imageUrl: null,
    rating: { average: 4, count: 10 },
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

function setup(options: { maxEntries?: number } = {}) {
  let now = 1_000_000;
  const inner = {
    listProducts: vi.fn<ProductProvider['listProducts']>(async () => [product('1')]),
    getProduct: vi.fn<ProductProvider['getProduct']>(async (id) => product(id)),
    listCategories: vi.fn<ProductProvider['listCategories']>(async () => [{ id: 'electronics', name: 'Electronics' }]),
    listProductsByCategory: vi.fn<ProductProvider['listProductsByCategory']>(async () => [product('1')]),
  };
  const cache = new CachingProductProvider(inner, { ttlMs: TTL_MS, now: () => now, ...options });
  const advance = (ms: number) => {
    now += ms;
  };
  return { inner, cache, advance };
}

describe('CachingProductProvider', () => {
  it('returns the wrapped provider result unchanged', async () => {
    const { cache } = setup();
    await expect(cache.listProducts()).resolves.toEqual([product('1')]);
    await expect(cache.listCategories()).resolves.toEqual([{ id: 'electronics', name: 'Electronics' }]);
  });

  it('serves repeat calls within the TTL from the cache', async () => {
    const { inner, cache, advance } = setup();

    await cache.listProducts();
    advance(TTL_MS - 1);
    await cache.listProducts();

    expect(inner.listProducts).toHaveBeenCalledTimes(1);
  });

  it('refetches once the TTL has elapsed', async () => {
    const { inner, cache, advance } = setup();

    await cache.listProducts();
    advance(TTL_MS);
    await cache.listProducts();

    expect(inner.listProducts).toHaveBeenCalledTimes(2);
  });

  it('does not cache failures: the next call retries upstream', async () => {
    const { inner, cache } = setup();
    inner.listProducts.mockRejectedValueOnce(new UpstreamUnavailableError());

    await expect(cache.listProducts()).rejects.toBeInstanceOf(UpstreamUnavailableError);
    await expect(cache.listProducts()).resolves.toEqual([product('1')]);

    expect(inner.listProducts).toHaveBeenCalledTimes(2);
  });

  it('shares one upstream request between concurrent misses (single-flight)', async () => {
    const { inner, cache } = setup();
    const pending = deferred<Product[]>();
    inner.listProducts.mockReturnValueOnce(pending.promise);

    const calls = [cache.listProducts(), cache.listProducts(), cache.listProducts()];
    pending.resolve([product('7')]);
    const results = await Promise.all(calls);

    expect(inner.listProducts).toHaveBeenCalledTimes(1);
    expect(results).toEqual([[product('7')], [product('7')], [product('7')]]);
  });

  it('rejects every concurrent caller when the shared request fails, then retries on the next call', async () => {
    const { inner, cache } = setup();
    const pending = deferred<Product[]>();
    inner.listProducts.mockReturnValueOnce(pending.promise);

    const calls = [cache.listProducts(), cache.listProducts()];
    pending.reject(new UpstreamUnavailableError());

    for (const call of calls) await expect(call).rejects.toBeInstanceOf(UpstreamUnavailableError);
    await expect(cache.listProducts()).resolves.toEqual([product('1')]);
    expect(inner.listProducts).toHaveBeenCalledTimes(2);
  });

  it('caches found products but not "not found" (null) results', async () => {
    const { inner, cache } = setup();
    inner.getProduct.mockImplementation(async (id) => (id === '404' ? null : product(id)));

    await cache.getProduct('1');
    await cache.getProduct('1');
    await cache.getProduct('404');
    await cache.getProduct('404');

    expect(inner.getProduct.mock.calls.map(([id]) => id)).toEqual(['1', '404', '404']);
  });

  it('keeps separate entries per product and per category', async () => {
    const { inner, cache } = setup();

    await cache.getProduct('1');
    await cache.getProduct('2');
    await cache.listProductsByCategory('electronics');
    await cache.listProductsByCategory('jewelery');
    await cache.listProductsByCategory('electronics');

    expect(inner.getProduct).toHaveBeenCalledTimes(2);
    expect(inner.listProductsByCategory.mock.calls.map(([id]) => id)).toEqual(['electronics', 'jewelery']);
  });

  it('evicts the oldest entry when the size cap is reached', async () => {
    const { inner, cache } = setup({ maxEntries: 2 });

    await cache.getProduct('1');
    await cache.getProduct('2');
    await cache.getProduct('3'); // evicts product:1
    await cache.getProduct('1'); // miss again

    expect(inner.getProduct.mock.calls.map(([id]) => id)).toEqual(['1', '2', '3', '1']);
  });

  it('turns a synchronous throw from the wrapped provider into a rejection and does not cache it', async () => {
    const { inner, cache } = setup();
    inner.listCategories.mockImplementationOnce(() => {
      throw new UpstreamUnavailableError();
    });

    await expect(cache.listCategories()).rejects.toBeInstanceOf(UpstreamUnavailableError);
    await expect(cache.listCategories()).resolves.toHaveLength(1);
  });
});
