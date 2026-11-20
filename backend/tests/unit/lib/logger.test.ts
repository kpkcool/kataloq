import { describe, expect, it } from 'vitest';
import { createLogger } from '../../../src/lib/logger.js';

function capture(level: 'debug' | 'info' | 'warn' | 'error' | 'silent' = 'debug') {
  const lines: Record<string, unknown>[] = [];
  const logger = createLogger({
    level,
    now: () => new Date('2026-11-19T10:00:00.000Z'),
    write: (line) => lines.push(JSON.parse(line) as Record<string, unknown>),
  });
  return { logger, lines };
}

describe('createLogger', () => {
  it('writes one JSON object per line with time, level, message and fields', () => {
    const { logger, lines } = capture();

    logger.info('hello', { productId: '1' });

    expect(lines).toEqual([{ time: '2026-11-19T10:00:00.000Z', level: 'info', msg: 'hello', productId: '1' }]);
  });

  it('drops lines below the configured level', () => {
    const { logger, lines } = capture('warn');

    logger.debug('d');
    logger.info('i');
    logger.warn('w');
    logger.error('e');

    expect(lines.map((line) => line['level'])).toEqual(['warn', 'error']);
  });

  it('writes nothing when silent', () => {
    const { logger, lines } = capture('silent');
    logger.error('e');
    expect(lines).toEqual([]);
  });

  it('adds child fields to every line', () => {
    const { logger, lines } = capture();

    logger.child({ requestId: 'r1' }).child({ component: 'X' }).info('m');

    expect(lines[0]).toEqual(expect.objectContaining({ requestId: 'r1', component: 'X' }));
  });

  it('serialises errors with name, message, code and cause', () => {
    const { logger, lines } = capture();
    const cause = Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:1025'), { code: 'ECONNREFUSED' });

    logger.warn('failed', { err: new Error('outer', { cause }) });

    const err = lines[0]?.['err'] as Record<string, unknown>;
    expect(err['name']).toBe('Error');
    expect(err['message']).toBe('outer');
    expect(err['cause']).toEqual(expect.objectContaining({ message: 'connect ECONNREFUSED 127.0.0.1:1025', code: 'ECONNREFUSED' }));
  });

  it('includes the inner errors of an AggregateError (whose own message is often empty)', () => {
    const { logger, lines } = capture();
    const inner = Object.assign(new Error('connect ECONNREFUSED ::1:1025'), { code: 'ECONNREFUSED' });
    const aggregate = Object.assign(new AggregateError([inner], ''), { code: 'ECONNREFUSED' });

    logger.warn('failed', { err: aggregate });

    const err = lines[0]?.['err'] as Record<string, unknown>;
    expect(err['code']).toBe('ECONNREFUSED');
    expect(err['errors']).toEqual([expect.objectContaining({ message: 'connect ECONNREFUSED ::1:1025', code: 'ECONNREFUSED' })]);
  });
});
