import type { Category, CategoryId, CategoryProducts, Product, ProductId } from '../domain/types.js';
import { NotFoundError } from '../domain/errors.js';
import { rankByRating } from '../domain/ranking.js';
import { matchesQuery } from '../domain/search.js';
import type { Logger } from '../lib/logger.js';
import type { ProductProvider } from '../providers/product/ProductProvider.js';

export interface CatalogueServiceOptions {
  /** Validated at startup: exactly 5 unique IDs, in display order. */
  readonly featuredProductIds: readonly ProductId[];
  /** Size of a category's "Top Rated" section. */
  readonly categoryTopRatedCount: number;
  readonly logger: Logger;
}

export interface SearchResult {
  /** The trimmed query that was matched. */
  readonly query: string;
  readonly products: Product[];
}

/**
 * Catalogue business rules. Depends only on the ProductProvider interface,
 * never on Fake Store, HTTP or Express.
 *
 * Upstream failures (UpstreamUnavailable/BadResponse/Timeout) are deliberately not
 * caught here: they propagate to the HTTP layer, which maps them to 502/504.
 */
export class CatalogueService {
  constructor(
    private readonly products: ProductProvider,
    private readonly options: CatalogueServiceOptions,
  ) {}

  /**
   * The owner's curated featured products, in configured order (D1, D13).
   * A configured product that no longer exists is skipped and logged, never replaced,
   * so the result can temporarily contain fewer than five.
   */
  async getFeaturedProducts(): Promise<Product[]> {
    const ids = this.options.featuredProductIds;
    const results = await Promise.all(ids.map((id) => this.products.getProduct(id)));

    const featured: Product[] = [];
    results.forEach((product, index) => {
      if (product) {
        featured.push(product);
      } else {
        this.options.logger.warn('Featured product unavailable; skipping it', { productId: ids[index] });
      }
    });
    return featured;
  }

  /** Every product, in the data source's original order (Home's "All Products" grid). */
  getAllProducts(): Promise<Product[]> {
    return this.products.listProducts();
  }

  getCategories(): Promise<Category[]> {
    return this.products.listCategories();
  }

  /**
   * A category's products ranked by rating (D8), split into the first N ("Top Rated")
   * and the rest ("All Products"). One ranked list cut in two, so the sections can't overlap.
   *
   * The category is checked BEFORE its products are fetched, so made-up category IDs
   * never reach the data source (or create cache entries).
   */
  async getCategoryProducts(categoryId: CategoryId): Promise<CategoryProducts> {
    const categories = await this.products.listCategories();
    const category = categories.find((candidate) => candidate.id === categoryId);
    if (!category) throw new NotFoundError('CATEGORY_NOT_FOUND', 'Category not found.');

    const ranked = rankByRating(await this.products.listProductsByCategory(categoryId));
    const topCount = this.options.categoryTopRatedCount;
    return { category, topRated: ranked.slice(0, topCount), additional: ranked.slice(topCount) };
  }

  /** Products matching the query, in the data source's original order (D9). */
  async searchProducts(query: string): Promise<SearchResult> {
    const trimmed = query.trim();
    if (trimmed === '') return { query: trimmed, products: [] };

    const all = await this.products.listProducts();
    return { query: trimmed, products: all.filter((product) => matchesQuery(product, trimmed)) };
  }

  async getProduct(id: ProductId): Promise<Product> {
    const product = await this.products.getProduct(id);
    if (!product) throw new NotFoundError('PRODUCT_NOT_FOUND', 'Product not found.');
    return product;
  }
}
