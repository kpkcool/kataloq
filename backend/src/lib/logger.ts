/**
 * Minimal structured logger: one JSON object per line on stdout.
 * JSON lines are what CloudWatch / most log pipelines expect, and this avoids a
 * logging dependency for a small service. Injected everywhere so tests stay quiet.
 *
 * Never pass request bodies or personal data (names, emails, phone numbers) here.
 */

export type LogLevel = 'debug' | 'info' | 'warn' | 'error' | 'silent';
export type LogFields = Readonly<Record<string, unknown>>;

export interface Logger {
  debug(message: string, fields?: LogFields): void;
  info(message: string, fields?: LogFields): void;
  warn(message: string, fields?: LogFields): void;
  error(message: string, fields?: LogFields): void;
  /** Returns a logger that adds `fields` to every line (e.g. a requestId). */
  child(fields: LogFields): Logger;
}

const LEVEL_ORDER: Record<LogLevel, number> = { debug: 10, info: 20, warn: 30, error: 40, silent: 100 };

export interface LoggerOptions {
  readonly level: LogLevel;
  readonly write?: (line: string) => void;
  readonly now?: () => Date;
  readonly base?: LogFields;
}

export function createLogger(options: LoggerOptions): Logger {
  const write = options.write ?? ((line: string) => process.stdout.write(`${line}\n`));
  const now = options.now ?? (() => new Date());
  const threshold = LEVEL_ORDER[options.level];
  const base = options.base ?? {};

  const log = (level: Exclude<LogLevel, 'silent'>, message: string, fields?: LogFields): void => {
    if (LEVEL_ORDER[level] < threshold) return;
    const entry: Record<string, unknown> = { time: now().toISOString(), level, msg: message, ...base };
    for (const [key, value] of Object.entries(fields ?? {})) {
      entry[key] = value instanceof Error ? serializeError(value) : value;
    }
    write(JSON.stringify(entry));
  };

  return {
    debug: (message, fields) => log('debug', message, fields),
    info: (message, fields) => log('info', message, fields),
    warn: (message, fields) => log('warn', message, fields),
    error: (message, fields) => log('error', message, fields),
    child: (fields) => createLogger({ ...options, base: { ...base, ...fields } }),
  };
}

/** A logger that discards everything. Useful in tests. */
export const silentLogger: Logger = createLogger({ level: 'silent' });

function serializeError(error: Error): Record<string, unknown> {
  const serialized: Record<string, unknown> = { name: error.name, message: error.message, stack: error.stack };
  if (error.cause !== undefined) {
    serialized['cause'] = error.cause instanceof Error ? serializeError(error.cause) : String(error.cause);
  }
  return serialized;
}
