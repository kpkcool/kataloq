import type { Category, Product } from '../../src/domain/types.js';
import type { ProductProvider } from '../../src/providers/product/ProductProvider.js';

export const electronics: Category = { id: 'electronics', name: 'Electronics' };
export const jewelery: Category = { id: 'jewelery', name: 'Jewelery' };
export const mensClothing: Category = { id: 'mens-clothing', name: "Men's Clothing" };

/** Builds a domain Product with sensible defaults; override only what a test cares about. */
export function makeProduct(overrides: Partial<Product> & { id: string }): Product {
  return {
    title: `Product ${overrides.id}`,
    description: `Description of product ${overrides.id}`,
    price: { amount: 10, currency: 'USD' },
    category: electronics,
    imageUrl: `https://images.test/${overrides.id}.png`,
    rating: { average: 3, count: 10 },
    ...overrides,
  };
}

/**
 * In-memory ProductProvider for service and integration tests.
 * Records calls, and can be told to fail so error propagation can be tested.
 */
export class InMemoryProductProvider implements ProductProvider {
  readonly calls: string[] = [];
  private failure: Error | undefined;

  constructor(
    private readonly products: Product[],
    private readonly categories: Category[] = uniqueCategories(products),
  ) {}

  /** Every subsequent call rejects with `error` (pass `undefined` to recover). */
  failWith(error: Error | undefined): void {
    this.failure = error;
  }

  async listProducts(): Promise<Product[]> {
    this.record('listProducts');
    return [...this.products];
  }

  async getProduct(id: string): Promise<Product | null> {
    this.record(`getProduct:${id}`);
    return this.products.find((product) => product.id === id) ?? null;
  }

  async listCategories(): Promise<Category[]> {
    this.record('listCategories');
    return [...this.categories];
  }

  async listProductsByCategory(categoryId: string): Promise<Product[]> {
    this.record(`listProductsByCategory:${categoryId}`);
    return this.products.filter((product) => product.category.id === categoryId);
  }

  private record(call: string): void {
    this.calls.push(call);
    if (this.failure) throw this.failure;
  }
}

function uniqueCategories(products: Product[]): Category[] {
  const byId = new Map<string, Category>();
  for (const product of products) byId.set(product.category.id, product.category);
  return [...byId.values()];
}
