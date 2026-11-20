import type { EmailMessage, EmailProvider } from '../../src/providers/email/EmailProvider.js';

/** Records sent messages; can be told to fail, to test that failure is never reported as success. */
export class FakeEmailProvider implements EmailProvider {
  readonly sent: EmailMessage[] = [];
  private failure: Error | undefined;

  failWith(error: Error | undefined): void {
    this.failure = error;
  }

  async send(message: EmailMessage): Promise<{ messageId: string }> {
    if (this.failure) throw this.failure;
    this.sent.push(message);
    return { messageId: `<fake-${this.sent.length}@kataloq.test>` };
  }
}
