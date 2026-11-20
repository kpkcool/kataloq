import { describe, expect, it } from 'vitest';
import { toCategory, toCategoryId, toProduct } from '../../../src/providers/product/fakeStoreMapper.js';
import { rawProducts } from '../../support/fakeStore.js';

describe('fakeStoreMapper', () => {
  it.each([
    ["men's clothing", 'mens-clothing', "Men's Clothing"],
    ["women's clothing", 'womens-clothing', "Women's Clothing"],
    ['electronics', 'electronics', 'Electronics'],
    ['jewelery', 'jewelery', 'Jewelery'],
  ])('maps category %j to id %j and name %j', (raw, id, name) => {
    expect(toCategory(raw)).toEqual({ id, name });
  });

  it('produces URL-safe slugs from awkward names', () => {
    expect(toCategoryId('  Home & Garden / Décor ')).toBe('home-garden-decor');
  });

  it('maps a Fake Store product to the Kataloq domain model', () => {
    const [raw] = rawProducts;
    if (!raw) throw new Error('fixture missing');

    expect(toProduct(raw)).toEqual({
      id: '1',
      title: 'Fjallraven - Foldsack No. 1 Backpack, Fits 15 Laptops',
      description: 'Your perfect pack for everyday use and walks in the forest.',
      price: { amount: 109.95, currency: 'USD' },
      category: { id: 'mens-clothing', name: "Men's Clothing" },
      imageUrl: 'https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_t.png',
      rating: { average: 3.9, count: 120 },
    });
  });

  it('defaults a missing rating to 0 / 0', () => {
    const { rating: _ignored, ...withoutRating } = rawProducts[0]!;
    expect(toProduct(withoutRating).rating).toEqual({ average: 0, count: 0 });
  });

  it('clamps an out-of-range rating into 0–5', () => {
    expect(toProduct({ ...rawProducts[0]!, rating: { rate: 7, count: 1 } }).rating.average).toBe(5);
  });

  it('rounds prices to 2 decimal places', () => {
    expect(toProduct({ ...rawProducts[0]!, price: 22.299999 }).price.amount).toBe(22.3);
  });

  it.each(['', 'not a url', 'http://insecure.example.com/a.png', 'ftp://example.com/a.png'])(
    'turns image %j into null (only https is passed on)',
    (image) => {
      expect(toProduct({ ...rawProducts[0]!, image }).imageUrl).toBeNull();
    },
  );
});
