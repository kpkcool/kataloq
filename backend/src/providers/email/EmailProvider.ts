/**
 * The contract any email vendor must satisfy (D3 / AD-2).
 *
 * Implementations resolve only when the provider has ACCEPTED the message, and
 * throw `EmailDeliveryError` otherwise. Callers must never report success to a
 * customer unless `send` resolved.
 */
export interface EmailMessage {
  readonly from: string;
  readonly to: string;
  /** A bare, validated email address (never a display name built from user input). */
  readonly replyTo?: string;
  readonly subject: string;
  /** Plain text only: no HTML, so customer input can't inject markup. */
  readonly text: string;
}

export interface EmailProvider {
  send(message: EmailMessage): Promise<{ messageId: string }>;
}
