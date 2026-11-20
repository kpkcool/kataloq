/**
 * Kataloq domain model.
 *
 * These types ARE the public API contract. They are deliberately independent of
 * any data source: provider adapters (e.g. Fake Store) map their own shapes into
 * these, and nothing vendor-specific crosses this boundary.
 */

/** String, not number, so a future data source with SKUs/UUIDs needs no contract change. */
export type ProductId = string;

/** URL-safe slug, e.g. "mens-clothing". */
export type CategoryId = string;

export interface Price {
  /** Amount in major units, rounded to 2 decimal places. */
  readonly amount: number;
  /** ISO 4217 currency code. */
  readonly currency: string;
}

export interface Rating {
  /** Average score, 0–5. */
  readonly average: number;
  /** Number of ratings, ≥ 0. */
  readonly count: number;
}

export interface Category {
  readonly id: CategoryId;
  /** Human-readable display name, e.g. "Men's Clothing". */
  readonly name: string;
}

export interface Product {
  readonly id: ProductId;
  readonly title: string;
  readonly description: string;
  readonly price: Price;
  readonly category: Category;
  /** Absolute https URL of the product image, or null if unavailable. Loaded by clients directly (AD-15). */
  readonly imageUrl: string | null;
  readonly rating: Rating;
}

export interface CategoryProducts {
  readonly category: Category;
  /** The first N products of the category ranked by rating ("Top Rated"). */
  readonly topRated: readonly Product[];
  /** Every remaining product of the category, continuing the same ranked order ("All Products"). */
  readonly additional: readonly Product[];
}
