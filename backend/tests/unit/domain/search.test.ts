import { describe, expect, it } from 'vitest';
import { matchesQuery } from '../../../src/domain/search.js';
import { makeProduct, mensClothing } from '../../support/products.js';

const backpack = makeProduct({
  id: '1',
  title: 'Fjallraven Foldsack Backpack',
  description: 'Stash your laptop (up to 15 inches) in the padded sleeve.',
  category: mensClothing,
});

describe('matchesQuery', () => {
  it.each(['Backpack', 'backpack', 'BACKPACK', 'foldsack back'])('matches the title case-insensitively: %j', (query) => {
    expect(matchesQuery(backpack, query)).toBe(true);
  });

  it('matches the description', () => {
    expect(matchesQuery(backpack, 'padded sleeve')).toBe(true);
  });

  it('matches the category name', () => {
    expect(matchesQuery(backpack, "men's")).toBe(true);
  });

  it('ignores surrounding whitespace in the query', () => {
    expect(matchesQuery(backpack, '   laptop  ')).toBe(true);
  });

  it('does not match unrelated text', () => {
    expect(matchesQuery(backpack, 'monitor')).toBe(false);
  });

  it('matches the whole phrase, not individual words', () => {
    expect(matchesQuery(backpack, 'backpack monitor')).toBe(false);
  });

  it('treats regex special characters literally', () => {
    expect(matchesQuery(backpack, '(up to 15')).toBe(true);
    expect(matchesQuery(backpack, '.*')).toBe(false);
  });

  it.each(['', '   '])('never matches a blank query %j', (query) => {
    expect(matchesQuery(backpack, query)).toBe(false);
  });
});
