import { z } from 'zod';

/**
 * Runtime schemas for Fake Store API responses (https://fakestoreapi.com).
 * Private to the Fake Store adapter: these shapes never leave it.
 *
 * Verified 2026-11-19:
 *   GET /products/categories → ["electronics","jewelery","men's clothing","women's clothing"]
 *   GET /products/:id        → product object; unknown id → HTTP 200 with an EMPTY body
 *   product shape            → { id, title, price, description, category, image, rating: { rate, count } }
 */

export const fakeStoreProductSchema = z.object({
  id: z.number().int().nonnegative(),
  title: z.string(),
  price: z.number().nonnegative(),
  description: z.string(),
  category: z.string().min(1),
  image: z.string(),
  rating: z
    .object({
      rate: z.number(),
      count: z.number().int().nonnegative(),
    })
    .optional(),
});

export type FakeStoreProduct = z.infer<typeof fakeStoreProductSchema>;

export const fakeStoreCategoryNamesSchema = z.array(z.string().min(1));
