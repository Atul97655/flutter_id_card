'use client';

import Link from 'next/link';
import { motion } from 'framer-motion';
import type { LucideIcon } from 'lucide-react';
import { AnimatedNumber, MOTION, staggerDelay } from '@/components/ui/primitives';

/**
 * One headline number.
 *
 * The tint is passed in rather than derived, because these tiles carry
 * different kinds of meaning - a review backlog is orange because it is work
 * waiting, a printed count is indigo because it is work finished - and the
 * caller is the only thing that knows which.
 */
export function StatTile({
  label,
  value,
  icon: Icon,
  tint,
  href,
  hint,
  index = 0,
  decimals = 0,
  prefix = '',
  suffix = '',
}: {
  label: string;
  value: number;
  icon: LucideIcon;
  tint: string;
  href?: string;
  hint?: string;
  index?: number;
  decimals?: number;
  prefix?: string;
  suffix?: string;
}) {
  const body = (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: MOTION.normal,
        ease: MOTION.ease,
        delay: staggerDelay(index),
      }}
      whileHover={href ? { y: -3 } : undefined}
      className={`glass h-full rounded-[var(--radius-panel)] p-4 transition-shadow ${
        href ? 'hover:shadow-[0_18px_36px_-16px_rgb(18_26_34/0.22)]' : ''
      }`}
    >
      <div className="flex items-start justify-between gap-2">
        <span
          className="grid size-9 shrink-0 place-items-center rounded-xl"
          style={{ background: `color-mix(in srgb, ${tint} 16%, transparent)`, color: tint }}
        >
          <Icon size={17} strokeWidth={2.1} />
        </span>
      </div>

      <p className="mt-3 text-[10.5px] font-bold uppercase tracking-wider text-ink-400">
        {label}
      </p>

      <AnimatedNumber
        value={value}
        prefix={prefix}
        suffix={suffix}
        decimals={decimals}
        className="mt-0.5 block text-[26px] font-bold leading-tight tracking-tight"
      />

      {hint ? (
        <p className="mt-0.5 text-[11.5px] leading-snug text-ink-400">{hint}</p>
      ) : null}
    </motion.div>
  );

  return href ? (
    <Link href={href} className="block h-full">
      {body}
    </Link>
  ) : (
    body
  );
}
