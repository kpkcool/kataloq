import type { Product } from './types.js';

export const SEARCH_QUERY_MAX_LENGTH = 100;

/**
 * Search matching rule (AS-4):
 * the trimmed query, as one phrase, is a case-insensitive substring of the product's
 * title, description or category name. No fuzzy matching, no relevance ranking (D9).
 *
 * Plain `includes` is used rather than a RegExp built from user input, so characters
 * like "(" or "*" are matched literally and can't cause ReDoS.
 */
export function matchesQuery(product: Product, query: string): boolean {
  const needle = normalize(query);
  if (needle === '') return false;

  return [product.title, product.description, product.category.name].some((field) =>
    normalize(field).includes(needle),
  );
}

function normalize(value: string): string {
  return value.trim().toLocaleLowerCase('en');
}
