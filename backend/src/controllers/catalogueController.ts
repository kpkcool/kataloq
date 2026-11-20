import type { RequestHandler } from 'express';
import { z } from 'zod';
import { CATEGORY_ID_PATTERN, PRODUCT_ID_PATTERN } from '../domain/validation.js';
import { SEARCH_QUERY_MAX_LENGTH } from '../domain/search.js';
import { parseInput } from '../http/validate.js';
import type { CatalogueService } from '../services/CatalogueService.js';

const productParams = z.object({
  productId: z.string().regex(PRODUCT_ID_PATTERN, { message: 'Invalid product ID.' }),
});

const categoryParams = z.object({
  categoryId: z.string().regex(CATEGORY_ID_PATTERN, { message: 'Invalid category ID.' }),
});

const searchQuery = z.object({
  q: z
    .string({ message: 'Enter a search term.' })
    .trim()
    .min(1, { message: 'Enter a search term.' })
    .max(SEARCH_QUERY_MAX_LENGTH, { message: `Search terms can be at most ${SEARCH_QUERY_MAX_LENGTH} characters.` }),
});

/**
 * HTTP adapters for the catalogue: validate input, call the service, shape the JSON.
 * No business rules live here.
 */
export function createCatalogueController(catalogue: CatalogueService) {
  const featured: RequestHandler = async (_req, res) => {
    res.json({ products: await catalogue.getFeaturedProducts() });
  };

  const allProducts: RequestHandler = async (_req, res) => {
    res.json({ products: await catalogue.getAllProducts() });
  };

  const categories: RequestHandler = async (_req, res) => {
    res.json({ categories: await catalogue.getCategories() });
  };

  const categoryProducts: RequestHandler = async (req, res) => {
    const { categoryId } = parseInput(categoryParams, req.params);
    res.json(await catalogue.getCategoryProducts(categoryId));
  };

  const search: RequestHandler = async (req, res) => {
    const { q } = parseInput(searchQuery, req.query);
    res.json(await catalogue.searchProducts(q));
  };

  const product: RequestHandler = async (req, res) => {
    const { productId } = parseInput(productParams, req.params);
    res.json({ product: await catalogue.getProduct(productId) });
  };

  return { featured, allProducts, categories, categoryProducts, search, product };
}
