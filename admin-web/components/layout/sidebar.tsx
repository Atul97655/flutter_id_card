'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import {
  BarChart3,
  Building2,
  ClipboardList,
  LayoutDashboard,
  Megaphone,
  MessageSquare,
  Printer,
  ScrollText,
  Settings,
  Users,
  X,
  type LucideIcon,
} from 'lucide-react';
import { MOTION } from '@/components/ui/primitives';
import { useStore } from '@/lib/store';

interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
  /** Shown as a live count badge when non-zero. */
  badgeKey?: 'pending' | 'unread';
}

/**
 * Grouped the way the office works, not the way the data is stored: the review
 * queue and printing sit together because they are one job, messaging is a
 * separate job, and configuration is something you touch once a term.
 */
const GROUPS: { label: string | null; items: NavItem[] }[] = [
  {
    label: null,
    items: [{ href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard }],
  },
  {
    label: 'Cards',
    items: [
      {
        href: '/requests',
        label: 'ID Card Requests',
        icon: ClipboardList,
        badgeKey: 'pending',
      },
      { href: '/print', label: 'Print Center', icon: Printer },
      { href: '/schools', label: 'Schools', icon: Building2 },
    ],
  },
  {
    label: 'People',
    items: [
      { href: '/messages', label: 'Messages', icon: MessageSquare, badgeKey: 'unread' },
      { href: '/broadcast', label: 'Bulk Message', icon: Megaphone },
      { href: '/accounts', label: 'Teachers & Schools', icon: Users },
    ],
  },
  {
    label: 'Records',
    items: [
      { href: '/reports', label: 'Reports', icon: BarChart3 },
      { href: '/audit', label: 'Activity', icon: ScrollText },
      { href: '/settings', label: 'Settings', icon: Settings },
    ],
  },
];

/**
 * The navigation rail on a wide screen.
 *
 * Hidden below `lg`, where 228px of a 375px phone would leave 147px for the
 * page itself. The same links appear there through [NavDrawer].
 */
export function Sidebar({
  pendingCount,
  unreadCount,
}: {
  pendingCount: number;
  unreadCount: number;
}) {
  return (
    <aside className="hidden w-[228px] shrink-0 flex-col px-3 py-5 lg:flex">
      <NavBody pendingCount={pendingCount} unreadCount={unreadCount} />
    </aside>
  );
}

/**
 * The same navigation, as a sheet that slides in from the left on a phone.
 *
 * A drawer rather than a bottom bar: there are eleven destinations in four
 * groups, and a bottom bar that fits five would mean hiding the rest behind a
 * "more" tab - which is where the things people rarely touch go to be
 * forgotten. The grouping is the point of this navigation and it survives here.
 */
export function NavDrawer({
  open,
  onClose,
  pendingCount,
  unreadCount,
}: {
  open: boolean;
  onClose: () => void;
  pendingCount: number;
  unreadCount: number;
}) {
  const pathname = usePathname();

  // Navigating is what closes it. Without this, tapping a link leaves the
  // sheet sitting over the page it just opened.
  useEffect(() => {
    onClose();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // A phone's back gesture is a system gesture, so Escape is the only key
  // dismissal - but this also runs on a small laptop window, where it is the
  // one people reach for.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  // The page behind must not scroll while the sheet is over it.
  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  return (
    <AnimatePresence>
      {open ? (
        <>
          <motion.button
            type="button"
            aria-label="Close menu"
            onClick={onClose}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: MOTION.fast }}
            className="fixed inset-0 z-40 bg-ink-900/35 backdrop-blur-[2px] lg:hidden"
          />

          <motion.aside
            initial={{ x: '-100%' }}
            animate={{ x: 0 }}
            exit={{ x: '-100%' }}
            transition={{ duration: MOTION.normal, ease: MOTION.ease }}
            className="fixed inset-y-0 left-0 z-50 flex w-[268px] max-w-[85vw] flex-col overflow-y-auto bg-[var(--color-surface-solid)] px-3 py-5 shadow-[0_0_60px_-10px_rgb(18_26_34/0.45)] lg:hidden"
          >
            <button
              type="button"
              onClick={onClose}
              aria-label="Close menu"
              className="absolute right-3 top-5 grid size-9 place-items-center rounded-xl text-ink-500 transition hover:bg-ink-400/10"
            >
              <X size={18} />
            </button>
            <NavBody pendingCount={pendingCount} unreadCount={unreadCount} />
          </motion.aside>
        </>
      ) : null}
    </AnimatePresence>
  );
}

function NavBody({
  pendingCount,
  unreadCount,
}: {
  pendingCount: number;
  unreadCount: number;
}) {
  const pathname = usePathname();

  const { config } = useStore();

  // Hidden rather than disabled: a greyed-out destination still asks to be
  // clicked, and an installation that does not print has no use for the
  // question.
  const groups = config.printingEnabled
    ? GROUPS
    : GROUPS.map((g) => ({
        ...g,
        items: g.items.filter((i) => i.href !== '/print'),
      })).filter((g) => g.items.length > 0);

  const badgeFor = (item: NavItem): number => {
    if (item.badgeKey === 'pending') return pendingCount;
    if (item.badgeKey === 'unread') return unreadCount;
    return 0;
  };

  return (
    <>
      <div className="mb-7 flex items-center gap-2.5 px-3">
        <div className="grid size-9 place-items-center rounded-xl bg-gradient-to-br from-mint-500 to-mint-700 text-white shadow-[0_6px_14px_-6px_rgb(38_133_115/0.8)]">
          <svg viewBox="0 0 24 24" className="size-5" fill="none" aria-hidden>
            <rect
              x="3"
              y="5.5"
              width="18"
              height="13"
              rx="3"
              stroke="currentColor"
              strokeWidth="1.8"
            />
            <circle cx="9" cy="11" r="2.1" fill="currentColor" />
            <path
              d="M5.9 16c.5-1.5 1.7-2.3 3.1-2.3s2.6.8 3.1 2.3"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
            />
            <path
              d="M14.8 10.2h4M14.8 13.4h4"
              stroke="currentColor"
              strokeWidth="1.6"
              strokeLinecap="round"
            />
          </svg>
        </div>
        <div className="leading-tight">
          <p className="text-[15px] font-bold tracking-tight text-ink-900">
            ID entity
          </p>
          <p className="text-[10.5px] font-medium text-ink-400">Admin panel</p>
        </div>
      </div>

      <nav className="flex flex-1 flex-col gap-5 overflow-y-auto">
        {groups.map((group) => (
          <div key={group.label ?? 'root'}>
            {group.label ? (
              <p className="mb-1.5 px-3 text-[10.5px] font-bold uppercase tracking-wider text-ink-400/80">
                {group.label}
              </p>
            ) : null}

            <ul className="flex flex-col gap-0.5">
              {group.items.map((item) => {
                const active =
                  pathname === item.href || pathname.startsWith(`${item.href}/`);
                const Icon = item.icon;
                const badge = badgeFor(item);

                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className="relative flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-[13px] font-medium transition-colors"
                    >
                      {/* One shared element slides between items rather than
                          each one fading, so the eye tracks the move. */}
                      {active ? (
                        <motion.span
                          layoutId="nav-active"
                          transition={{ duration: MOTION.normal, ease: MOTION.ease }}
                          className="absolute inset-0 rounded-xl bg-gradient-to-r from-mint-500 to-mint-600 shadow-[0_6px_16px_-8px_rgb(38_133_115/0.9)]"
                        />
                      ) : null}

                      <span
                        className={`relative z-10 flex flex-1 items-center gap-2.5 ${
                          active ? 'text-white' : 'text-ink-500 hover:text-ink-700'
                        }`}
                      >
                        <Icon size={17} strokeWidth={active ? 2.3 : 1.9} />
                        <span className="flex-1 truncate">{item.label}</span>

                        {badge > 0 ? (
                          <span
                            className={`nums rounded-full px-1.5 py-0.5 text-[10.5px] font-bold ${
                              active
                                ? 'bg-white/25 text-white'
                                : 'bg-[var(--color-status-pending)] text-white'
                            }`}
                          >
                            {badge > 99 ? '99+' : badge}
                          </span>
                        ) : null}
                      </span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>
    </>
  );
}
