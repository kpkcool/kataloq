import { describe, expect, it, vi } from 'vitest';
import { FakeStoreProductProvider } from '../../../src/providers/product/FakeStoreProductProvider.js';
import {
  UpstreamBadResponseError,
  UpstreamTimeoutError,
  UpstreamUnavailableError,
} from '../../../src/domain/errors.js';
import type { Logger } from '../../../src/lib/logger.js';
import { jsonResponse, rawCategories, rawProducts, textResponse } from '../../support/fakeStore.js';

function makeLogger(): Logger & { warn: ReturnType<typeof vi.fn> } {
  const logger = { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn(), child: vi.fn() };
  logger.child.mockReturnValue(logger);
  return logger;
}

function makeProvider(fetchImpl: (url: string, init?: RequestInit) => Promise<Response>, timeoutMs = 1_000) {
  const fetchMock = vi.fn(fetchImpl);
  const logger = makeLogger();
  const provider = new FakeStoreProductProvider({
    baseUrl: 'https://fakestore.test/',
    timeoutMs,
    userAgent: 'kataloq-api/test',
    logger,
    fetch: fetchMock as unknown as typeof fetch,
  });
  return { provider, fetchMock, logger };
}

describe('FakeStoreProductProvider', () => {
  describe('listProducts', () => {
    it('requests /products with JSON and User-Agent headers and maps the result', async () => {
      const { provider, fetchMock } = makeProvider(async () => jsonResponse(rawProducts));

      const products = await provider.listProducts();

      expect(fetchMock).toHaveBeenCalledTimes(1);
      const [url, init] = fetchMock.mock.calls[0]!;
      expect(url).toBe('https://fakestore.test/products');
      expect(init?.headers).toEqual({ accept: 'application/json', 'user-agent': 'kataloq-api/test' });
      expect(init?.signal).toBeInstanceOf(AbortSignal);
      expect(products.map((product) => product.id)).toEqual(['1', '5', '9', '18']);
      expect(products[0]?.category).toEqual({ id: 'mens-clothing', name: "Men's Clothing" });
    });

    it('skips an invalid item, logs a warning and keeps the rest', async () => {
      const { provider, logger } = makeProvider(async () =>
        jsonResponse([rawProducts[0], { id: 'oops', title: 42 }, rawProducts[1]]),
      );

      const products = await provider.listProducts();

      expect(products.map((product) => product.id)).toEqual(['1', '5']);
      expect(logger.warn).toHaveBeenCalledWith('Skipping invalid product from Fake Store', expect.objectContaining({ index: 1 }));
    });

    it('throws UpstreamBadResponseError when the body is not an array', async () => {
      const { provider } = makeProvider(async () => jsonResponse({ products: [] }));
      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamBadResponseError);
    });

    it('throws UpstreamBadResponseError when the body is not JSON', async () => {
      const { provider } = makeProvider(async () => textResponse('<html>oops</html>'));
      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamBadResponseError);
    });

    it('throws UpstreamBadResponseError on an empty body', async () => {
      const { provider } = makeProvider(async () => textResponse(''));
      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamBadResponseError);
    });
  });

  describe('getProduct', () => {
    it('returns the mapped product', async () => {
      const { provider, fetchMock } = makeProvider(async () => jsonResponse(rawProducts[2]));

      const product = await provider.getProduct('9');

      expect(fetchMock.mock.calls[0]?.[0]).toBe('https://fakestore.test/products/9');
      expect(product?.id).toBe('9');
      expect(product?.category.id).toBe('electronics');
    });

    it('returns null for HTTP 200 with an empty body (verified Fake Store behaviour for unknown IDs)', async () => {
      const { provider } = makeProvider(async () => textResponse(''));
      await expect(provider.getProduct('999')).resolves.toBeNull();
    });

    it('returns null for a JSON null body', async () => {
      const { provider } = makeProvider(async () => textResponse('null'));
      await expect(provider.getProduct('999')).resolves.toBeNull();
    });

    it('returns null for HTTP 404', async () => {
      const { provider } = makeProvider(async () => textResponse('Not found', { status: 404 }));
      await expect(provider.getProduct('999')).resolves.toBeNull();
    });

    it.each(['abc', '0', '-1', '1.5', '12345678901'])('returns null for %j without calling upstream', async (id) => {
      const { provider, fetchMock } = makeProvider(async () => jsonResponse(rawProducts[0]));

      await expect(provider.getProduct(id)).resolves.toBeNull();
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('throws UpstreamBadResponseError for a malformed product', async () => {
      const { provider } = makeProvider(async () => jsonResponse({ id: 1, title: 'no price' }));
      await expect(provider.getProduct('1')).rejects.toBeInstanceOf(UpstreamBadResponseError);
    });
  });

  describe('listCategories', () => {
    it('maps category names to ids and display names, in upstream order', async () => {
      const { provider, fetchMock } = makeProvider(async () => jsonResponse(rawCategories));

      const categories = await provider.listCategories();

      expect(fetchMock.mock.calls[0]?.[0]).toBe('https://fakestore.test/products/categories');
      expect(categories).toEqual([
        { id: 'electronics', name: 'Electronics' },
        { id: 'jewelery', name: 'Jewelery' },
        { id: 'mens-clothing', name: "Men's Clothing" },
        { id: 'womens-clothing', name: "Women's Clothing" },
      ]);
    });

    it('drops duplicates that map to the same id', async () => {
      const { provider } = makeProvider(async () => jsonResponse(['electronics', 'Electronics']));
      await expect(provider.listCategories()).resolves.toEqual([{ id: 'electronics', name: 'Electronics' }]);
    });

    it('throws UpstreamBadResponseError for a non-array body', async () => {
      const { provider } = makeProvider(async () => jsonResponse({}));
      await expect(provider.listCategories()).rejects.toBeInstanceOf(UpstreamBadResponseError);
    });
  });

  describe('listProductsByCategory', () => {
    it('returns only products of that category, in upstream order', async () => {
      const { provider } = makeProvider(async () => jsonResponse(rawProducts));
      const products = await provider.listProductsByCategory('mens-clothing');
      expect(products.map((product) => product.id)).toEqual(['1']);
    });

    it('returns [] for an unknown category', async () => {
      const { provider } = makeProvider(async () => jsonResponse(rawProducts));
      await expect(provider.listProductsByCategory('furniture')).resolves.toEqual([]);
    });
  });

  describe('upstream failures', () => {
    it.each([500, 502, 503, 429, 401])('maps HTTP %i to UpstreamUnavailableError', async (status) => {
      const { provider } = makeProvider(async () => textResponse('error', { status }));
      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamUnavailableError);
    });

    it('maps a Cloudflare challenge (403 + cf-mitigated) to UpstreamUnavailableError and logs why', async () => {
      const { provider, logger } = makeProvider(async () =>
        textResponse('<html>Just a moment…</html>', { status: 403, headers: { 'cf-mitigated': 'challenge' } }),
      );

      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamUnavailableError);
      expect(logger.warn).toHaveBeenCalledWith(
        'Fake Store returned a Cloudflare challenge; product data unavailable',
        expect.objectContaining({ status: 403 }),
      );
    });

    it('maps a network error to UpstreamUnavailableError', async () => {
      const { provider } = makeProvider(async () => {
        throw new TypeError('fetch failed');
      });
      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamUnavailableError);
    });

    it('maps a real timeout to UpstreamTimeoutError', async () => {
      // A fetch that never answers but honours the abort signal, like the real one.
      const { provider } = makeProvider(
        (_url, init) =>
          new Promise<Response>((_resolve, reject) => {
            init?.signal?.addEventListener('abort', () => reject(init.signal?.reason));
          }),
        20,
      );

      await expect(provider.listProducts()).rejects.toBeInstanceOf(UpstreamTimeoutError);
    });

    it('keeps internal details out of the client-facing message', async () => {
      const { provider } = makeProvider(async () => textResponse('secret upstream detail', { status: 500 }));
      await expect(provider.listProducts()).rejects.toThrow('Product data is temporarily unavailable. Please try again.');
    });
  });
});
