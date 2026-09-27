'use client';

import { use, useCallback, useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import QRCode from 'qrcode';
import { Download, Printer, RefreshCw } from 'lucide-react';
import { ensureJoinCode, issueJoinCode, watchJoinCode } from '@/lib/joins';
import { useStore } from '@/lib/store';
import type { JoinCode } from '@/lib/types';
import { Banner, Button, MOTION, Panel } from '@/components/ui/primitives';

/**
 * A school's QR join code (A8).
 *
 * This page prints. What comes off the printer gets pinned to a staffroom
 * noticeboard, photographed by whoever walks past, and forwarded around a
 * WhatsApp group - so the sheet has to say, on the sheet itself, that the
 * code is an invitation and not a password. Somebody reading the paper
 * without ever seeing this screen is the normal case, not the edge case.
 */
export default function SchoolQrPage({
  params,
}: {
  params: Promise<{ schoolId: string }>;
}) {
  const { schoolId } = use(params);
  const { schools } = useStore();
  const school = schools.find((s) => s.id === schoolId);

  const [code, setCode] = useState<JoinCode | null>(null);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(
    () =>
      watchJoinCode(
        schoolId,
        (c) => {
          setCode(c);
          setReady(true);
        },
        (e) => {
          setError(`Could not read this school's code: ${e.message}`);
          setReady(true);
        },
      ),
    [schoolId],
  );

  // A school registered before this feature existed has no code at all. Mint
  // one on first view rather than making the office find a button for it -
  // there is exactly one sensible thing to do here and no decision to make.
  useEffect(() => {
    if (!ready || code || !school) return;
    let cancelled = false;
    void (async () => {
      try {
        await ensureJoinCode(schoolId, school.name, null);
      } catch (e) {
        if (!cancelled) setError(`Could not issue a code: ${(e as Error).message}`);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [ready, code, school, schoolId]);

  async function rotate() {
    if (!school) return;
    setBusy(true);
    setError(null);
    try {
      await issueJoinCode(schoolId, school.name, code?.token ?? null);
    } catch (e) {
      setError(`Could not issue a new code: ${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  if (!school) {
    return (
      <Banner tone="warn" title="School not found">
        No school with the code {schoolId} is in this installation.
      </Banner>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="px-1 print:hidden">
        <h1 className="text-[20px] font-semibold text-ink-700">
          {school.name} — QR Join Code
        </h1>
        <p className="mt-0.5 text-[13px] text-ink-400">
          Print this and pin it in the staffroom
        </p>
      </div>

      {error ? (
        <Banner tone="error" title="Something went wrong">
          {error}
        </Banner>
      ) : null}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,420px)_1fr]">
        <CodeSheet
          schoolName={school.name}
          schoolId={school.id}
          token={code?.token ?? null}
        />

        <div className="flex flex-col gap-4 print:hidden">
          <Banner tone="warn" title="This code is an invitation, not a password">
            <p>
              Scanning it connects a teacher to this school and puts their name
              in your Pending Joins list. They cannot see or send anything until
              you assign them a class and section.
            </p>
            <p className="mt-2">
              That is why it is safe to print it, photograph it, or put it on a
              noticeboard — which is what will happen to it.
            </p>
          </Banner>

          <Panel>
            <div className="flex flex-col gap-3 p-5">
              <h2 className="text-[15px] font-semibold text-ink-700">
                If the code leaks outside the school
              </h2>
              <p className="text-[13px] leading-relaxed text-ink-500">
                Issue a new one. Every printed or shared copy of the current
                code stops working immediately.
              </p>
              <p className="text-[13px] leading-relaxed text-ink-500">
                Teachers who already joined are not affected — they stay
                connected and keep their class assignment.
              </p>
              <div className="flex items-center gap-3 pt-1">
                <Button
                  variant="danger"
                  icon={RefreshCw}
                  onClick={rotate}
                  busy={busy}
                  disabled={!ready}
                >
                  Issue a new code
                </Button>
                {code?.issuedAt ? (
                  <span className="text-[12px] text-ink-400">
                    Last issued{' '}
                    {new Date(code.issuedAt).toLocaleDateString(undefined, {
                      day: 'numeric',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </span>
                ) : null}
              </div>
            </div>
          </Panel>
        </div>
      </div>
    </div>
  );
}

/**
 * The printable sheet.
 *
 * Rendered to a canvas rather than an `<img>` of a data URL so that
 * "Download PNG" can hand over the real bitmap at print resolution. 640px of
 * QR at error-correction level M scans reliably from across a staffroom even
 * after a photocopy.
 */
function CodeSheet({
  schoolName,
  schoolId,
  token,
}: {
  schoolName: string;
  schoolId: string;
  token: string | null;
}) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [drawn, setDrawn] = useState(false);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !token) return;
    let cancelled = false;
    void QRCode.toCanvas(canvas, token, {
      width: 640,
      margin: 2,
      errorCorrectionLevel: 'M',
      color: { dark: '#0f172a', light: '#ffffff' },
    })
      .then(() => {
        if (!cancelled) setDrawn(true);
      })
      .catch(() => {
        if (!cancelled) setDrawn(false);
      });
    return () => {
      cancelled = true;
    };
  }, [token]);

  const download = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const link = document.createElement('a');
    link.download = `${schoolId}-join-code.png`;
    link.href = canvas.toDataURL('image/png');
    link.click();
  }, [schoolId]);

  return (
    <Panel>
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: MOTION.normal, ease: MOTION.ease }}
        className="flex flex-col items-center gap-3 p-6 text-center"
      >
        <h2 className="text-[16px] font-bold tracking-wide text-ink-700">
          {schoolName}
        </h2>
        <p className="text-[12px] text-ink-400">School ID: {schoolId}</p>

        <div className="my-2 rounded-xl border border-black/10 bg-white p-3">
          <canvas
            ref={canvasRef}
            className="block size-[220px]"
            aria-label={`QR join code for ${schoolName}`}
          />
          {!token || !drawn ? (
            <p className="pt-2 text-[12px] text-ink-400">Preparing code…</p>
          ) : null}
        </div>

        <p className="max-w-[16rem] text-[12.5px] leading-relaxed text-ink-500">
          Teachers open the app, tap &ldquo;Scan my school QR code&rdquo;, and
          point their camera at this.
        </p>

        {/* On paper, the reader has no banner beside them to explain this. */}
        <p className="hidden max-w-[18rem] text-[11.5px] leading-relaxed text-ink-400 print:block">
          This code is an invitation, not a password. Scanning it only puts a
          teacher in the school office&apos;s pending list — the office still
          assigns their class before they can send anything.
        </p>

        <div className="flex gap-2 pt-2 print:hidden">
          <Button variant="outline" icon={Download} onClick={download} disabled={!drawn}>
            Download PNG
          </Button>
          <Button icon={Printer} onClick={() => window.print()} disabled={!drawn}>
            Print code sheet
          </Button>
        </div>
      </motion.div>
    </Panel>
  );
}
