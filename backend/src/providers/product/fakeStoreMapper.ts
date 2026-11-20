import type { Category, CategoryId, Product } from '../../domain/types.js';
import type { FakeStoreProduct } from './fakeStoreSchemas.js';

/**
 * Maps Fake Store shapes into Kataloq's domain model.
 * This is the anti-corruption layer: vendor quirks stop here.
 */

/** Fake Store prices carry no currency. Assumption AS-10: treat them as USD. */
export const FAKE_STORE_CURRENCY = 'USD';

/** "men's clothing" → "mens-clothing" */
export function toCategoryId(rawName: string): CategoryId {
  return rawName
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/['’]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** "men's clothing" → "Men's Clothing" (Fake Store's own spelling, e.g. "jewelery", is kept). */
export function toCategoryName(rawName: string): string {
  return rawName
    .trim()
    .split(/\s+/)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

export function toCategory(rawName: string): Category {
  return { id: toCategoryId(rawName), name: toCategoryName(rawName) };
}

export function toProduct(raw: FakeStoreProduct): Product {
  return {
    id: String(raw.id),
    title: raw.title.trim(),
    description: raw.description.trim(),
    price: { amount: Math.round(raw.price * 100) / 100, currency: FAKE_STORE_CURRENCY },
    category: toCategory(raw.category),
    imageUrl: toHttpsUrlOrNull(raw.image),
    rating: {
      average: clamp(raw.rating?.rate ?? 0, 0, 5),
      count: raw.rating?.count ?? 0,
    },
  };
}

/** Only absolute https URLs are passed to clients; anything else becomes null (client shows a placeholder). */
function toHttpsUrlOrNull(value: string): string | null {
  try {
    const url = new URL(value.trim());
    return url.protocol === 'https:' ? url.href : null;
  } catch {
    return null;
  }
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
