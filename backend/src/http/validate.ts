import type { z } from 'zod';
import { ValidationError } from '../domain/errors.js';

/**
 * Parses untrusted input (params, query or body) with a zod schema.
 * On failure throws ValidationError with one entry per invalid field, which the
 * error handler turns into 400 VALIDATION_ERROR with `details`.
 */
export function parseInput<Schema extends z.ZodType>(schema: Schema, input: unknown): z.output<Schema> {
  const result = schema.safeParse(input);
  if (result.success) return result.data;

  const seen = new Set<string>();
  const details = result.error.issues
    .map((issue) => ({ field: issue.path.map(String).join('.') || 'body', message: issue.message }))
    .filter((detail) => (seen.has(detail.field) ? false : (seen.add(detail.field), true)));

  throw new ValidationError(details);
}
