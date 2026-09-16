'use client';

import { motion, type HTMLMotionProps } from 'framer-motion';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import type { ApprovalStatus } from '@/lib/types';
import { APPROVAL_LABELS } from '@/lib/types';
import {
  CheckCircle2,
  Clock,
  Printer,
  XCircle,
  type LucideIcon,
} from 'lucide-react';

/**
 * The shared vocabulary of the panel.
 *
 * Motion timings live here rather than being sprinkled through screens, so the
 * whole app decelerates the same way. Nothing runs longer than ~350ms: this is
 * an office tool someone uses for hours, and past that point animation reads as
 * lag rather than polish.
 */
export const MOTION = {
  fast: 0.14,
  normal: 0.24,
  slow: 0.34,
  ease: [0.22, 0.61, 0.36, 1] as const,
  /** Per-item delay in a staggered list, capped so long lists never wait. */
  stagger: 0.035,
  maxStagger: 8,
};

export function staggerDelay(index: number): number {
  return Math.min(index, MOTION.maxStagger) * MOTION.stagger;
}

// ---------------------------------------------------------------------------
// Surfaces
// ---------------------------------------------------------------------------

export function Panel({
  children,
  className = '',
  index = 0,
  ...rest
}: { children: ReactNode; className?: string; index?: number } & HTMLMotionProps<'div'>) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
      className={`glass rounded-[var(--radius-panel)] ${className}`}
      {...rest}
    >
      {children}
    </motion.div>
  );
}

export function PanelHeader({
  title,
  action,
}: {
  title: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-3 px-5 pt-4 pb-3">
      <h2 className="text-[15px] font-semibold text-ink-700">{title}</h2>
      {action}
    </div>
  );
}

/** A tappable surface that presses in slightly, for tactile feedback. */
export function Pressable({
  children,
  onClick,
  className = '',
  disabled = false,
}: {
  children: ReactNode;
  onClick?: () => void;
  className?: string;
  disabled?: boolean;
}) {
  return (
    <motion.button
      type="button"
      disabled={disabled}
      onClick={onClick}
      whileTap={disabled ? undefined : { scale: 0.975 }}
      transition={{ duration: MOTION.fast, ease: MOTION.ease }}
      className={`text-left disabled:cursor-not-allowed disabled:opacity-55 ${className}`}
    >
      {children}
    </motion.button>
  );
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

const STATUS_VISUALS: Record<
  ApprovalStatus,
  { color: string; bg: string; border: string; Icon: LucideIcon }
> = {
  pending: {
    color: 'var(--color-status-pending)',
    bg: 'rgb(245 124 0 / 0.12)',
    border: 'rgb(245 124 0 / 0.35)',
    Icon: Clock,
  },
  approved: {
    color: 'var(--color-status-approved)',
    bg: 'rgb(46 125 50 / 0.12)',
    border: 'rgb(46 125 50 / 0.35)',
    Icon: CheckCircle2,
  },
  rejected: {
    color: 'var(--color-status-rejected)',
    bg: 'rgb(198 40 40 / 0.12)',
    border: 'rgb(198 40 40 / 0.35)',
    Icon: XCircle,
  },
  printed: {
    color: 'var(--color-status-printed)',
    bg: 'rgb(69 39 160 / 0.12)',
    border: 'rgb(69 39 160 / 0.35)',
    Icon: Printer,
  },
};

export function statusVisual(s: ApprovalStatus) {
  return STATUS_VISUALS[s];
}

/**
 * The review state of one entry.
 *
 * Colour is always paired with a distinct icon. Pending/approved is
 * orange/green, exactly the pair red-green colour blindness collapses, so hue
 * alone can never be the only signal.
 */
export function StatusChip({
  status,
  dense = false,
}: {
  status: ApprovalStatus;
  dense?: boolean;
}) {
  const v = STATUS_VISUALS[status];
  const Icon = v.Icon;
  return (
    <span
      className={`inline-flex shrink-0 items-center gap-1.5 rounded-full font-semibold ${
        dense ? 'px-2 py-0.5 text-[11px]' : 'px-2.5 py-1 text-xs'
      }`}
      style={{ color: v.color, background: v.bg, border: `1px solid ${v.border}` }}
    >
      <Icon size={dense ? 11 : 13} strokeWidth={2.4} />
      {APPROVAL_LABELS[status]}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Numbers
// ---------------------------------------------------------------------------

/**
 * Counts up when the value changes rather than snapping.
 *
 * A number that animates draws the eye to what moved, which is the whole point
 * of a dashboard that updates live while someone is looking at it.
 */
export function AnimatedNumber({
  value,
  className = '',
  prefix = '',
  suffix = '',
  decimals = 0,
}: {
  value: number;
  className?: string;
  prefix?: string;
  suffix?: string;
  decimals?: number;
}) {
  const [shown, setShown] = useState(value);
  const fromRef = useRef(value);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    const from = fromRef.current;
    const to = value;
    if (from === to) return;

    // Respect the OS setting - jump straight to the value.
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      fromRef.current = to;
      setShown(to);
      return;
    }

    const start = performance.now();
    const ms = MOTION.slow * 1000;

    const tick = (now: number) => {
      const t = Math.min((now - start) / ms, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      setShown(from + (to - from) * eased);
      if (t < 1) {
        rafRef.current = requestAnimationFrame(tick);
      } else {
        fromRef.current = to;
      }
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
      fromRef.current = to;
    };
  }, [value]);

  return (
    <span className={`nums ${className}`}>
      {prefix}
      {shown.toFixed(decimals)}
      {suffix}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

export function EmptyState({
  icon: Icon,
  title,
  body,
  action,
}: {
  icon: LucideIcon;
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: MOTION.normal, ease: MOTION.ease }}
      className="flex flex-col items-center justify-center px-8 py-14 text-center"
    >
      <Icon size={40} strokeWidth={1.5} className="text-ink-400/60" />
      <p className="mt-3.5 text-[15px] font-semibold text-ink-700">{title}</p>
      <p className="mt-1.5 max-w-sm text-[13px] leading-relaxed text-ink-500">{body}</p>
      {action ? <div className="mt-4">{action}</div> : null}
    </motion.div>
  );
}

/** A shimmering placeholder, so a slow query looks like loading not breakage. */
export function Skeleton({ className = '' }: { className?: string }) {
  return (
    <div
      className={`animate-pulse rounded-lg bg-ink-400/12 ${className}`}
      aria-hidden
    />
  );
}

export function Spinner({ size = 16 }: { size?: number }) {
  return (
    <span
      className="inline-block animate-spin rounded-full border-2 border-current border-t-transparent align-[-2px]"
      style={{ width: size, height: size }}
      aria-hidden
    />
  );
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

export function Button({
  children,
  onClick,
  variant = 'primary',
  size = 'md',
  disabled = false,
  busy = false,
  type = 'button',
  className = '',
  icon: Icon,
}: {
  children?: ReactNode;
  onClick?: () => void;
  variant?: 'primary' | 'ghost' | 'outline' | 'danger' | 'success';
  size?: 'sm' | 'md';
  disabled?: boolean;
  busy?: boolean;
  type?: 'button' | 'submit';
  className?: string;
  icon?: LucideIcon;
}) {
  const variants: Record<string, string> = {
    primary:
      'bg-mint-600 text-white hover:bg-mint-700 shadow-[0_6px_16px_-6px_rgb(38_133_115/0.6)]',
    success:
      'bg-[var(--color-status-approved)] text-white hover:brightness-110',
    danger: 'bg-[var(--color-status-rejected)] text-white hover:brightness-110',
    outline:
      'border border-ink-400/25 bg-white/70 text-ink-600 hover:bg-white hover:border-ink-400/40',
    ghost: 'text-ink-500 hover:bg-white/70 hover:text-ink-700',
  };

  return (
    <motion.button
      type={type}
      onClick={onClick}
      disabled={disabled || busy}
      whileTap={disabled || busy ? undefined : { scale: 0.97 }}
      transition={{ duration: MOTION.fast, ease: MOTION.ease }}
      className={`inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-55 ${
        size === 'sm' ? 'px-3 py-1.5 text-[12.5px]' : 'px-4 py-2.5 text-[13.5px]'
      } ${variants[variant]} ${className}`}
    >
      {busy ? <Spinner size={14} /> : Icon ? <Icon size={size === 'sm' ? 14 : 16} /> : null}
      {children}
    </motion.button>
  );
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-[12.5px] font-semibold text-ink-600">
        {label}
      </span>
      {children}
      {hint ? <span className="mt-1 block text-[11.5px] text-ink-400">{hint}</span> : null}
    </label>
  );
}

export const inputClass =
  'w-full rounded-xl border border-ink-400/20 bg-white/80 px-3.5 py-2.5 text-[13.5px] text-ink-700 outline-none transition placeholder:text-ink-400/70 focus:border-mint-500 focus:ring-2 focus:ring-mint-500/25';

export function Banner({
  tone = 'info',
  title,
  children,
  action,
}: {
  tone?: 'info' | 'warn' | 'error' | 'success';
  title: string;
  children?: ReactNode;
  action?: ReactNode;
}) {
  const tones: Record<string, { bg: string; border: string; fg: string }> = {
    info: { bg: 'rgb(2 136 209 / 0.09)', border: 'rgb(2 136 209 / 0.3)', fg: '#0277bd' },
    warn: { bg: 'rgb(245 124 0 / 0.1)', border: 'rgb(245 124 0 / 0.32)', fg: '#e65100' },
    error: { bg: 'rgb(198 40 40 / 0.09)', border: 'rgb(198 40 40 / 0.3)', fg: '#c62828' },
    success: {
      bg: 'rgb(46 125 50 / 0.09)',
      border: 'rgb(46 125 50 / 0.3)',
      fg: '#2e7d32',
    },
  };
  const t = tones[tone];

  return (
    <motion.div
      initial={{ opacity: 0, y: -6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: MOTION.normal, ease: MOTION.ease }}
      className="rounded-[var(--radius-card)] px-4 py-3"
      style={{ background: t.bg, border: `1px solid ${t.border}` }}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-[13px] font-semibold" style={{ color: t.fg }}>
            {title}
          </p>
          {children ? (
            <div className="mt-1 text-[12.5px] leading-relaxed text-ink-600">
              {children}
            </div>
          ) : null}
        </div>
        {action}
      </div>
    </motion.div>
  );
}
