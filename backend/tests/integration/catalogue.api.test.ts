import { describe, expect, it } from 'vitest';
import request from 'supertest';
import {
  UpstreamBadResponseError,
  UpstreamTimeoutError,
  UpstreamUnavailableError,
} from '../../src/domain/errors.js';
import { buildTestApp } from '../support/app.js';
import { electronics, jewelery, makeProduct, mensClothing } from '../support/products.js';

const products = [
  makeProduct({ id: '1', title: 'Backpack', category: mensClothing, rating: { average: 3.9, count: 120 } }),
  makeProduct({ id: '5', title: 'Dragon Bracelet', category: jewelery, rating: { average: 4.6, count: 400 } }),
  makeProduct({ id: '9', title: 'WD Hard Drive', category: electronics, rating: { average: 3.3, count: 203 } }),
  makeProduct({ id: '10', title: 'SanDisk SSD', category: electronics, rating: { average: 2.9, count: 470 } }),
  makeProduct({ id: '11', title: 'Silicon Power SSD', category: electronics, rating: { average: 4.8, count: 319 } }),
  makeProduct({ id: '12', title: 'WD Gaming Drive', category: electronics, rating: { average: 4.8, count: 400 } }),
  makeProduct({ id: '14', title: 'Samsung Monitor', category: electronics, rating: { average: 2.2, count: 140 } }),
];

const ids = (list: { id: string }[]) => list.map((product) => product.id);

function setup(overrides: { featuredProductIds?: string[] } = {}) {
  return buildTestApp({ products, featuredProductIds: overrides.featuredProductIds ?? ['1', '5', '9', '14', '12'] });
}

function expectErrorBody(body: unknown, code: string) {
  expect(body).toEqual({
    error: { code, message: expect.any(String), requestId: expect.any(String) },
  });
}

describe('Catalogue API', () => {
  describe('GET /health', () => {
    it('returns ok without touching the product source', async () => {
      const { app, provider } = setup();

      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ status: 'ok' });
      expect(provider.calls).toEqual([]);
    });
  });

  describe('GET /api/v1/products/featured', () => {
    it('returns the five configured products in configured order', async () => {
      const response = await request(setup().app).get('/api/v1/products/featured');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toMatch(/application\/json/);
      expect(ids(response.body.products)).toEqual(['1', '5', '9', '14', '12']);
    });

    it('returns products in the Kataloq contract shape (no Fake Store fields)', async () => {
      const response = await request(setup().app).get('/api/v1/products/featured');

      expect(response.body.products[0]).toEqual({
        id: '1',
        title: 'Backpack',
        description: 'Description of product 1',
        price: { amount: 10, currency: 'USD' },
        category: { id: 'mens-clothing', name: "Men's Clothing" },
        imageUrl: 'https://images.test/1.png',
        rating: { average: 3.9, count: 120 },
      });
    });

    it('skips an unavailable featured product and still returns 200', async () => {
      const { app, logLines } = setup({ featuredProductIds: ['1', '404', '9', '14', '12'] });

      const response = await request(app).get('/api/v1/products/featured');

      expect(response.status).toBe(200);
      expect(ids(response.body.products)).toEqual(['1', '9', '14', '12']);
      expect(logLines).toContainEqual(
        expect.objectContaining({ level: 'warn', msg: 'Featured product unavailable; skipping it', productId: '404' }),
      );
    });
  });

  describe('GET /api/v1/products', () => {
    it('returns every product in data-source order', async () => {
      const response = await request(setup().app).get('/api/v1/products');

      expect(response.status).toBe(200);
      expect(ids(response.body.products)).toEqual(['1', '5', '9', '10', '11', '12', '14']);
    });
  });

  describe('GET /api/v1/categories', () => {
    it('lists categories', async () => {
      const response = await request(setup().app).get('/api/v1/categories');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ categories: [mensClothing, jewelery, electronics] });
    });
  });

  describe('GET /api/v1/categories/:categoryId/products', () => {
    it('returns the top 3 by rating then the rest, in ranked order', async () => {
      const response = await request(setup().app).get('/api/v1/categories/electronics/products');

      expect(response.status).toBe(200);
      expect(response.body.category).toEqual(electronics);
      expect(ids(response.body.topRated)).toEqual(['12', '11', '9']);
      expect(ids(response.body.additional)).toEqual(['10', '14']);
    });

    it('returns 404 CATEGORY_NOT_FOUND for an unknown category', async () => {
      const response = await request(setup().app).get('/api/v1/categories/furniture/products');

      expect(response.status).toBe(404);
      expectErrorBody(response.body, 'CATEGORY_NOT_FOUND');
    });

    it.each(['Electronics', 'men%27s%20clothing', 'a'.repeat(65)])('returns 400 for invalid category id %j', async (id) => {
      const response = await request(setup().app).get(`/api/v1/categories/${id}/products`);

      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe('VALIDATION_ERROR');
      expect(response.body.error.details).toEqual([{ field: 'categoryId', message: 'Invalid category ID.' }]);
    });
  });

  describe('GET /api/v1/products/search', () => {
    it('returns only matching products in data-source order, with the trimmed query', async () => {
      const response = await request(setup().app).get('/api/v1/products/search').query({ q: '  ssd ' });

      expect(response.status).toBe(200);
      expect(response.body.query).toBe('ssd');
      expect(ids(response.body.products)).toEqual(['10', '11']);
    });

    it('returns 200 with an empty list when nothing matches', async () => {
      const response = await request(setup().app).get('/api/v1/products/search').query({ q: 'unicorn' });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ query: 'unicorn', products: [] });
    });

    it.each([
      ['missing', ''],
      ['blank', '?q=%20%20'],
      ['too long', `?q=${'x'.repeat(101)}`],
      ['repeated parameter', '?q=a&q=b'],
    ])('returns 400 for a %s query', async (_label, queryString) => {
      const response = await request(setup().app).get(`/api/v1/products/search${queryString}`);

      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe('VALIDATION_ERROR');
      expect(response.body.error.details[0].field).toBe('q');
    });
  });

  describe('GET /api/v1/products/:productId', () => {
    it('returns the product', async () => {
      const response = await request(setup().app).get('/api/v1/products/9');

      expect(response.status).toBe(200);
      expect(response.body.product.title).toBe('WD Hard Drive');
    });

    it('returns 404 PRODUCT_NOT_FOUND for an unknown product', async () => {
      const response = await request(setup().app).get('/api/v1/products/999');

      expect(response.status).toBe(404);
      expectErrorBody(response.body, 'PRODUCT_NOT_FOUND');
    });

    it('returns 400 for an invalid product id', async () => {
      const response = await request(setup().app).get('/api/v1/products/bad%20id');

      expect(response.status).toBe(400);
      expect(response.body.error.details).toEqual([{ field: 'productId', message: 'Invalid product ID.' }]);
    });
  });

  describe('upstream failures', () => {
    it.each([
      [new UpstreamUnavailableError(), 502, 'UPSTREAM_UNAVAILABLE'],
      [new UpstreamBadResponseError(), 502, 'UPSTREAM_BAD_RESPONSE'],
      [new UpstreamTimeoutError(), 504, 'UPSTREAM_TIMEOUT'],
    ])('maps %s to HTTP %i %s', async (error, status, code) => {
      const { app, provider } = setup();
      provider.failWith(error);

      for (const path of ['/api/v1/products', '/api/v1/products/featured', '/api/v1/categories', '/api/v1/products/search?q=a', '/api/v1/products/1']) {
        const response = await request(app).get(path);
        expect(response.status).toBe(status);
        expectErrorBody(response.body, code);
      }
    });

    it('returns a generic 500 for unexpected errors, without leaking internals', async () => {
      const { app, provider, logLines } = setup();
      provider.failWith(new Error('database password is hunter2'));

      const response = await request(app).get('/api/v1/products/featured');

      expect(response.status).toBe(500);
      expect(response.body).toEqual({
        error: { code: 'INTERNAL_ERROR', message: 'Something went wrong. Please try again.', requestId: expect.any(String) },
      });
      expect(JSON.stringify(response.body)).not.toContain('hunter2');
      expect(logLines).toContainEqual(expect.objectContaining({ level: 'error', msg: 'unhandled error' }));
    });
  });

  describe('HTTP behaviour', () => {
    it('returns 404 ROUTE_NOT_FOUND for unknown routes', async () => {
      const response = await request(setup().app).get('/api/v1/nope');

      expect(response.status).toBe(404);
      expectErrorBody(response.body, 'ROUTE_NOT_FOUND');
    });

    it('returns 400 for a malformed JSON body', async () => {
      const response = await request(setup().app)
        .post('/api/v1/anything')
        .set('Content-Type', 'application/json')
        .send('{"broken":');

      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 413 for a body over 10 KB', async () => {
      const response = await request(setup().app)
        .post('/api/v1/anything')
        .set('Content-Type', 'application/json')
        .send({ padding: 'x'.repeat(11 * 1024) });

      expect(response.status).toBe(413);
      expect(response.body.error.code).toBe('PAYLOAD_TOO_LARGE');
    });

    it('sets a request id header that matches the id in error bodies', async () => {
      const response = await request(setup().app).get('/api/v1/products/999');

      expect(response.headers['x-request-id']).toEqual(expect.any(String));
      expect(response.body.error.requestId).toBe(response.headers['x-request-id']);
    });

    it('reuses a safe incoming X-Request-Id and replaces an unsafe one', async () => {
      const { app } = setup();

      const reused = await request(app).get('/health').set('X-Request-Id', 'client-req-12345');
      const replaced = await request(app).get('/health').set('X-Request-Id', 'bad id with spaces');

      expect(reused.headers['x-request-id']).toBe('client-req-12345');
      expect(replaced.headers['x-request-id']).not.toBe('bad id with spaces');
    });

    it('sets basic security headers and hides the framework', async () => {
      const response = await request(setup().app).get('/health');

      expect(response.headers['x-content-type-options']).toBe('nosniff');
      expect(response.headers['x-powered-by']).toBeUndefined();
    });

    it('logs health checks at debug level only, so they do not flood the logs', async () => {
      const { app, logLines } = setup();

      await request(app).get('/health');

      const line = logLines.find((entry) => entry['msg'] === 'request completed');
      expect(line).toEqual(expect.objectContaining({ level: 'debug', path: '/health' }));
    });

    it('logs one line per request with method, path and status, but not the query string', async () => {
      const { app, logLines } = setup();

      await request(app).get('/api/v1/products/search').query({ q: 'private term' });

      const line = logLines.find((entry) => entry['msg'] === 'request completed');
      expect(line).toEqual(
        expect.objectContaining({ method: 'GET', path: '/api/v1/products/search', status: 200, requestId: expect.any(String) }),
      );
      expect(JSON.stringify(logLines)).not.toContain('private term');
    });
  });
});
