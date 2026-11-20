import { describe, expect, it, vi } from 'vitest';
import { CatalogueService } from '../../../src/services/CatalogueService.js';
import { NotFoundError, UpstreamTimeoutError, UpstreamUnavailableError } from '../../../src/domain/errors.js';
import type { Logger } from '../../../src/lib/logger.js';
import type { Product } from '../../../src/domain/types.js';
import { InMemoryProductProvider, electronics, jewelery, makeProduct, mensClothing } from '../../support/products.js';

const ids = (products: readonly Product[]) => products.map((product) => product.id);

function makeLogger() {
  const logger = { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn(), child: vi.fn() };
  logger.child.mockReturnValue(logger);
  return logger satisfies Logger;
}

// Electronics: six products, ranked by average then count, with one exact tie (e4, e5).
const catalogue: Product[] = [
  makeProduct({ id: 'e1', category: electronics, rating: { average: 3.3, count: 203 } }),
  makeProduct({ id: 'e2', category: electronics, rating: { average: 4.8, count: 319 } }),
  makeProduct({ id: 'e3', category: electronics, rating: { average: 4.8, count: 400 } }),
  makeProduct({ id: 'e4', category: electronics, rating: { average: 2.9, count: 470 } }),
  makeProduct({ id: 'e5', category: electronics, rating: { average: 2.9, count: 470 } }),
  makeProduct({ id: 'e6', category: electronics, rating: { average: 4.0, count: 10 } }),
  makeProduct({ id: 'j1', category: jewelery, title: 'Gold Bracelet', rating: { average: 4.6, count: 400 } }),
  makeProduct({ id: 'j2', category: jewelery, title: 'Silver Ring', rating: { average: 3.0, count: 70 } }),
  makeProduct({ id: 'm1', category: mensClothing, title: 'Backpack', description: 'Fits a laptop' }),
];

function setup(options: { featured?: string[]; topRated?: number; products?: Product[] } = {}) {
  const provider = new InMemoryProductProvider(options.products ?? catalogue);
  const logger = makeLogger();
  const service = new CatalogueService(provider, {
    featuredProductIds: options.featured ?? ['j1', 'e2', 'm1', 'e6', 'j2'],
    categoryTopRatedCount: options.topRated ?? 3,
    logger,
  });
  return { service, provider, logger };
}

describe('CatalogueService', () => {
  describe('getFeaturedProducts', () => {
    it('returns all five configured products in configured order', async () => {
      const { service } = setup();
      expect(ids(await service.getFeaturedProducts())).toEqual(['j1', 'e2', 'm1', 'e6', 'j2']);
    });

    it('skips an unavailable product, logs a warning and never substitutes another', async () => {
      const { service, logger } = setup({ featured: ['j1', 'gone', 'm1', 'e6', 'j2'] });

      const featured = await service.getFeaturedProducts();

      expect(ids(featured)).toEqual(['j1', 'm1', 'e6', 'j2']);
      expect(logger.warn).toHaveBeenCalledWith('Featured product unavailable; skipping it', { productId: 'gone' });
    });

    it('returns an empty list (not an error) if no configured product exists', async () => {
      const { service } = setup({ featured: ['x1', 'x2', 'x3', 'x4', 'x5'] });
      expect(await service.getFeaturedProducts()).toEqual([]);
    });

    it('propagates an upstream failure instead of treating it as "unavailable"', async () => {
      const { service, provider, logger } = setup();
      provider.failWith(new UpstreamTimeoutError());

      await expect(service.getFeaturedProducts()).rejects.toBeInstanceOf(UpstreamTimeoutError);
      expect(logger.warn).not.toHaveBeenCalled();
    });
  });

  describe('getAllProducts', () => {
    it('returns every product in the data source order', async () => {
      const { service } = setup();
      expect(ids(await service.getAllProducts())).toEqual(ids(catalogue));
    });

    it('propagates upstream failures', async () => {
      const { service, provider } = setup();
      provider.failWith(new UpstreamUnavailableError());
      await expect(service.getAllProducts()).rejects.toBeInstanceOf(UpstreamUnavailableError);
    });
  });

  describe('getCategories', () => {
    it('returns the provider categories', async () => {
      const { service } = setup();
      expect(await service.getCategories()).toEqual([electronics, jewelery, mensClothing]);
    });
  });

  describe('getCategoryProducts', () => {
    it('puts the 3 best-rated products in topRated and the rest in additional, in ranked order', async () => {
      const { service } = setup();

      const result = await service.getCategoryProducts('electronics');

      expect(result.category).toEqual(electronics);
      // e3 & e2 tie on 4.8 → count decides (400 > 319); e4 & e5 tie on both → original order.
      expect(ids(result.topRated)).toEqual(['e3', 'e2', 'e6']);
      expect(ids(result.additional)).toEqual(['e1', 'e4', 'e5']);
    });

    it('never puts a product in both sections, and loses none', async () => {
      const { service } = setup();

      const { topRated, additional } = await service.getCategoryProducts('electronics');
      const all = [...ids(topRated), ...ids(additional)];

      expect(new Set(all).size).toBe(all.length);
      expect([...all].sort()).toEqual(['e1', 'e2', 'e3', 'e4', 'e5', 'e6']);
    });

    it('only returns products from the requested category', async () => {
      const { service } = setup();
      const { topRated, additional } = await service.getCategoryProducts('jewelery');
      expect([...topRated, ...additional].every((product) => product.category.id === 'jewelery')).toBe(true);
    });

    it('returns everything as topRated when the category has 3 or fewer products', async () => {
      const { service } = setup();

      const result = await service.getCategoryProducts('jewelery');

      expect(ids(result.topRated)).toEqual(['j1', 'j2']);
      expect(result.additional).toEqual([]);
    });

    it('respects CATEGORY_TOP_RATED_COUNT', async () => {
      const { service } = setup({ topRated: 1 });

      const result = await service.getCategoryProducts('electronics');

      expect(ids(result.topRated)).toEqual(['e3']);
      expect(result.additional).toHaveLength(5);
    });

    it('throws CATEGORY_NOT_FOUND for an unknown category without fetching its products', async () => {
      const { service, provider } = setup();

      const error = await service.getCategoryProducts('furniture').catch((caught: unknown) => caught);

      expect(error).toBeInstanceOf(NotFoundError);
      expect((error as NotFoundError).code).toBe('CATEGORY_NOT_FOUND');
      expect(provider.calls).toEqual(['listCategories']);
    });

    it('propagates upstream failures', async () => {
      const { service, provider } = setup();
      provider.failWith(new UpstreamUnavailableError());
      await expect(service.getCategoryProducts('electronics')).rejects.toBeInstanceOf(UpstreamUnavailableError);
    });
  });

  describe('searchProducts', () => {
    it('returns only matching products, in the data source order', async () => {
      const { service } = setup({
        products: [
          makeProduct({ id: 'p1', title: 'Blue Shirt' }),
          makeProduct({ id: 'p2', title: 'Red Hat' }),
          makeProduct({ id: 'p3', title: 'Plain tee', description: 'A soft cotton shirt' }),
          makeProduct({ id: 'p4', title: 'SHIRT pack', rating: { average: 5, count: 999 } }),
        ],
      });

      const result = await service.searchProducts('shirt');

      expect(result.query).toBe('shirt');
      expect(ids(result.products)).toEqual(['p1', 'p3', 'p4']); // not re-ranked by rating
    });

    it('returns the trimmed query and an empty list when nothing matches', async () => {
      const { service } = setup();
      expect(await service.searchProducts('  zzz  ')).toEqual({ query: 'zzz', products: [] });
    });

    it('returns no products for a blank query without calling the data source', async () => {
      const { service, provider } = setup();

      expect(await service.searchProducts('   ')).toEqual({ query: '', products: [] });
      expect(provider.calls).toEqual([]);
    });

    it('propagates upstream failures', async () => {
      const { service, provider } = setup();
      provider.failWith(new UpstreamUnavailableError());
      await expect(service.searchProducts('shirt')).rejects.toBeInstanceOf(UpstreamUnavailableError);
    });
  });

  describe('getProduct', () => {
    it('returns the product', async () => {
      const { service } = setup();
      expect((await service.getProduct('m1')).title).toBe('Backpack');
    });

    it('throws PRODUCT_NOT_FOUND for an unknown product', async () => {
      const { service } = setup();
      const error = await service.getProduct('nope').catch((caught: unknown) => caught);
      expect(error).toBeInstanceOf(NotFoundError);
      expect((error as NotFoundError).code).toBe('PRODUCT_NOT_FOUND');
    });
  });
});
