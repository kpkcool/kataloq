import type { Category, CategoryId, Product, ProductId } from '../../domain/types.js';

/**
 * The contract any product data source must satisfy.
 *
 * Owned by the domain, implemented by adapters (Fake Store today). Services depend
 * only on this interface, so replacing the data source means writing one new
 * adapter and changing the composition root. Nothing else changes.
 *
 * Failure contract: implementations throw `UpstreamUnavailableError`,
 * `UpstreamBadResponseError` or `UpstreamTimeoutError` (see domain/errors.ts).
 * "Does not exist" is NOT an error: `getProduct` resolves to `null`, and
 * `listProductsByCategory` resolves to `[]` for an unknown category.
 */
export interface ProductProvider {
  /** Every product, in the data source's own order. */
  listProducts(): Promise<Product[]>;

  /** One product, or `null` if it does not exist. */
  getProduct(id: ProductId): Promise<Product | null>;

  /** Every category, in the data source's own order. */
  listCategories(): Promise<Category[]>;

  /** Products in one category, in the data source's own order; `[]` if the category is unknown. */
  listProductsByCategory(categoryId: CategoryId): Promise<Product[]>;
}
