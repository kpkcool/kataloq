import express, { type Router } from 'express';
import type { CatalogueService } from '../services/CatalogueService.js';
import { createCatalogueController } from '../controllers/catalogueController.js';

/** Catalogue endpoints, mounted under /api/v1. */
export function catalogueRoutes(catalogue: CatalogueService): Router {
  const controller = createCatalogueController(catalogue);
  const router = express.Router();

  // Literal paths before /products/:productId so "featured" and "search" are never read as IDs.
  router.get('/products/featured', controller.featured);
  router.get('/products/search', controller.search);
  router.get('/products/:productId', controller.product);

  router.get('/categories', controller.categories);
  router.get('/categories/:categoryId/products', controller.categoryProducts);

  return router;
}
