/**
 * Sending the code, via Resend's HTTP API.
 *
 * HTTP rather than their SDK: one POST with a JSON body is the whole
 * integration, and a dependency that ships its own HTTP stack into a
 * cold-starting function costs more than it saves.
 */

export interface MailerConfig {
  apiKey: string;
  /** Must be on a domain verified in Resend, or every send is rejected. */
  from: string;
  /** Shown in the subject and body so the code is attributable. */
  appName: string;
}

export class EmailSendError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'EmailSendError';
  }
}

/**
 * The message itself.
 *
 * Plain and short on purpose. A code email that looks like marketing gets
 * filed as marketing, and the one thing it has to do is survive a spam
 * filter and be readable at a glance on a phone held in one hand.
 *
 * The code is in the subject as well as the body. Most phones show enough of
 * a subject line in the notification to read six digits, which saves opening
 * the mail app at all.
 */
export function buildOtpEmail(args: {
  code: string;
  appName: string;
  ttlMinutes: number;
}): { subject: string; html: string; text: string } {
  const { code, appName, ttlMinutes } = args;

  const text = [
    `${code} is your ${appName} sign-in code.`,
    '',
    `It expires in ${ttlMinutes} minutes and can be used once.`,
    '',
    'If you did not ask to sign in, ignore this email. Nobody can use the',
    'code without it, and it will expire on its own.',
  ].join('\n');

  // Inline styles and a table-free layout: every mail client strips <style>
  // blocks differently, and this has to render the same in Gmail on Android
  // as in whatever the office uses.
  const html = `<!doctype html>
<html>
  <body style="margin:0;padding:24px;background:#f4f6f8;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#13232f;">
    <div style="max-width:420px;margin:0 auto;background:#ffffff;border-radius:14px;padding:28px;">
      <p style="margin:0 0 6px;font-size:13px;color:#64748b;">${escapeHtml(appName)}</p>
      <p style="margin:0 0 18px;font-size:17px;font-weight:600;">Your sign-in code</p>
      <p style="margin:0 0 18px;font-size:34px;font-weight:700;letter-spacing:7px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;">${escapeHtml(code)}</p>
      <p style="margin:0 0 10px;font-size:14px;line-height:1.5;">
        It expires in ${ttlMinutes} minutes and can be used once.
      </p>
      <p style="margin:0;font-size:13px;line-height:1.5;color:#64748b;">
        If you did not ask to sign in, ignore this email. Nobody can use the
        code without it, and it will expire on its own.
      </p>
    </div>
  </body>
</html>`;

  return { subject: `${code} is your ${appName} sign-in code`, html, text };
}

function escapeHtml(raw: string): string {
  return raw
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * Posts the message to Resend.
 *
 * Throws [EmailSendError] on anything but a 2xx, so the caller can decide
 * whether to roll the stored code back. It must: a code that exists in
 * Firestore but never reached anybody is a dead end the person cannot get out
 * of except by waiting out the cooldown.
 */
export async function sendViaResend(args: {
  config: MailerConfig;
  to: string;
  subject: string;
  html: string;
  text: string;
}): Promise<void> {
  const { config, to, subject, html, text } = args;

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: config.from, to: [to], subject, html, text }),
    // Resend is normally sub-second. Ten is generous and still well inside
    // the callable timeout, so a hung provider surfaces as a clean error the
    // app can retry rather than as a function that eventually gets killed.
    signal: AbortSignal.timeout(10_000),
  });

  if (!response.ok) {
    // The body carries Resend's own reason - an unverified domain, a bad key.
    // Worth keeping: without it every failure reads as "500".
    const detail = await response.text().catch(() => '');
    throw new EmailSendError(
      `Resend rejected the message (${response.status}): ${detail.slice(0, 300)}`,
      response.status,
    );
  }
}
