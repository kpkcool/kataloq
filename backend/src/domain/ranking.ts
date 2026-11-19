import type { Product } from './types.js';

/**
 * Ranks products for a category page (D8):
 *   1. rating average, highest first
 *   2. rating count, highest first
 *   3. products tied on both keep their original (data-source) order
 *
 * Rule 3 needs no code: Array.prototype.sort is stable (guaranteed since ES2019).
 * Returns a new array; the input is not modified.
 */
export function rankByRating(products: readonly Product[]): Product[] {
  return [...products].sort(
    (a, b) => b.rating.average - a.rating.average || b.rating.count - a.rating.count,
  );
}
