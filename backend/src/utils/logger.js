/**
 * Writes a structured log line to stdout with ISO timestamp and level.
 * @param {'info'|'warn'|'error'} level
 * @param {string} message
 * @param {Record<string, unknown>} [meta]
 */
export function log(level, message, meta = {}) {
  const line = {
    ts: new Date().toISOString(),
    level,
    message,
    ...meta,
  };
  const fn = level === 'error' ? console.error : console.log;
  fn(JSON.stringify(line));
}
