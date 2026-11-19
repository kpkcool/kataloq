import { describe, expect, it } from 'vitest';
import { rankByRating } from '../../../src/domain/ranking.js';
import { makeProduct } from '../../support/products.js';

const rated = (id: string, average: number, count: number) => makeProduct({ id, rating: { average, count } });
const ids = (products: { id: string }[]) => products.map((product) => product.id);

describe('rankByRating', () => {
  it('sorts by rating average, highest first', () => {
    expect(ids(rankByRating([rated('a', 3.1, 5), rated('b', 4.7, 5), rated('c', 2, 5)]))).toEqual(['b', 'a', 'c']);
  });

  it('breaks average ties by rating count, highest first', () => {
    expect(ids(rankByRating([rated('a', 4, 10), rated('b', 4, 300), rated('c', 4, 50)]))).toEqual(['b', 'c', 'a']);
  });

  it('keeps the original order when average and count are both equal', () => {
    const tied = [rated('x', 4, 10), rated('y', 4, 10), rated('z', 4, 10)];
    expect(ids(rankByRating(tied))).toEqual(['x', 'y', 'z']);
  });

  it('puts unrated products (0 / 0) last', () => {
    expect(ids(rankByRating([rated('none', 0, 0), rated('some', 1, 1)]))).toEqual(['some', 'none']);
  });

  it('does not modify the input array', () => {
    const input = [rated('a', 1, 1), rated('b', 5, 1)];
    rankByRating(input);
    expect(ids(input)).toEqual(['a', 'b']);
  });

  it('handles an empty list', () => {
    expect(rankByRating([])).toEqual([]);
  });
});
