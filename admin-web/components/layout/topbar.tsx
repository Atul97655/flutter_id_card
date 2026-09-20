'use client';

import { useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { Bell, LogOut, Menu, Search, WifiOff, X } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { useStore } from '@/lib/store';
import { MOTION, StatusChip } from '@/components/ui/primitives';
import { hasPhoto, isPrintable } from '@/lib/types';
import { NavDrawer } from '@/components/layout/sidebar';
import Link from 'next/link';

export function Topbar({
  greeting,
  title,
  onSearch,
  searchValue,
  searchPlaceholder = 'Search students, schools, accounts',
}: {
  greeting: string;
  title: string;
  onSearch?: (v: string) => void;
  searchValue?: string;
  searchPlaceholder?: string;
}) {
  const { profile, logOut } = useAuth();
  const { entries, chats } = useStore();
  const [showBell, setShowBell] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  const [showNav, setShowNav] = useState(false);
  // On a phone the search box cannot sit permanently beside a 24px title, so
  // it opens over the header instead of being cut from the feature set.
  const [showSearch, setShowSearch] = useState(false);

  const pending = entries.filter((e) => e.approvalStatus === 'pending');
  const unreadChats = chats.filter((c) => c.unreadFor.includes(profile?.uid ?? ''));
  // Approved but unprintable: the photo never arrived. Worth surfacing,
  // because these look ready in every count until someone tries to print.
  const missingPhoto = entries.filter(
    (e) => isPrintable(e.approvalStatus) && !hasPhoto(e),
  );
  const alerts = pending.length + unreadChats.length;

  const initials =
    (profile?.displayName || profile?.email || 'A')
      .split(/[\s@.]+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((s) => s[0]?.toUpperCase())
      .join('') || 'A';

  const header = (
    <header className="flex items-start justify-between gap-3 pb-1">
      <NavDrawer
        open={showNav}
        onClose={() => setShowNav(false)}
        pendingCount={pending.length}
        unreadCount={unreadChats.length}
      />

      <div className="flex min-w-0 items-start gap-2">
        {/* The only way to reach the other pages on a phone, where the rail
            is hidden. */}
        <button
          type="button"
          onClick={() => setShowNav(true)}
          aria-label="Open menu"
          className="-ml-1 mt-1 grid size-10 shrink-0 place-items-center rounded-xl text-ink-600 transition hover:bg-white/70 active:scale-95 lg:hidden"
        >
          <Menu size={20} />
        </button>

        <div className="min-w-0">
          <p className="text-[12px] font-medium text-mint-600 sm:text-[13px]">
            {greeting}
          </p>
          <h1 className="mt-0.5 truncate text-[22px] font-bold leading-tight tracking-tight text-ink-900 sm:text-[26px] lg:text-[30px]">
            {title}
          </h1>
        </div>
      </div>

      <div className="flex items-center gap-1.5 pt-1 sm:gap-2.5">
        {onSearch ? (
          <button
            type="button"
            onClick={() => setShowSearch((v) => !v)}
            aria-label={showSearch ? 'Close search' : 'Search'}
            className="grid size-10 place-items-center rounded-xl text-ink-600 transition hover:bg-white/70 active:scale-95 md:hidden"
          >
            {showSearch ? <X size={18} /> : <Search size={18} />}
          </button>
        ) : null}

        {onSearch ? (
          <div className="relative hidden md:block">
            <Search
              size={15}
              className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-400"
            />
            <input
              value={searchValue ?? ''}
              onChange={(e) => onSearch(e.target.value)}
              placeholder={searchPlaceholder}
              className="w-[248px] rounded-full border border-white/70 bg-white/65 py-2 pl-9 pr-3.5 text-[13px] text-ink-700 outline-none backdrop-blur transition placeholder:text-ink-400/80 focus:w-[300px] focus:border-mint-400 focus:bg-white/90"
            />
          </div>
        ) : null}

        {/* Notifications */}
        <div className="relative">
          <button
            type="button"
            onClick={() => {
              setShowBell((v) => !v);
              setShowMenu(false);
            }}
            aria-label={`Notifications${alerts ? `, ${alerts} waiting` : ''}`}
            className="glass relative grid size-9 place-items-center rounded-full text-ink-600 transition hover:text-ink-900"
          >
            <Bell size={16} />
            {alerts > 0 ? (
              <span className="absolute -right-0.5 -top-0.5 grid min-w-[17px] place-items-center rounded-full bg-[var(--color-status-pending)] px-1 text-[10px] font-bold text-white">
                {alerts > 9 ? '9+' : alerts}
              </span>
            ) : null}
          </button>

          <AnimatePresence>
            {showBell ? (
              <>
                <button
                  type="button"
                  aria-hidden
                  tabIndex={-1}
                  className="fixed inset-0 z-40 cursor-default"
                  onClick={() => setShowBell(false)}
                />
                <motion.div
                  initial={{ opacity: 0, y: -8, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -8, scale: 0.97 }}
                  transition={{ duration: MOTION.normal, ease: MOTION.ease }}
                  className="glass absolute right-0 top-11 z-50 w-[310px] max-w-[calc(100vw-2rem)] overflow-hidden rounded-[var(--radius-card)] p-1.5"
                >
                  <p className="px-3 py-2 text-[12px] font-bold uppercase tracking-wide text-ink-400">
                    Needs attention
                  </p>

                  {alerts === 0 && missingPhoto.length === 0 ? (
                    <p className="px-3 pb-3 pt-1 text-[13px] text-ink-500">
                      Nothing waiting. The queue is clear.
                    </p>
                  ) : (
                    <div className="flex flex-col gap-1 pb-1">
                      {pending.length > 0 ? (
                        <Link
                          href="/requests"
                          onClick={() => setShowBell(false)}
                          className="flex items-center gap-2.5 rounded-xl px-3 py-2.5 transition hover:bg-white/70"
                        >
                          <StatusChip status="pending" dense />
                          <span className="text-[13px] text-ink-600">
                            {pending.length} card
                            {pending.length === 1 ? '' : 's'} awaiting review
                          </span>
                        </Link>
                      ) : null}

                      {unreadChats.length > 0 ? (
                        <Link
                          href="/messages"
                          onClick={() => setShowBell(false)}
                          className="flex items-center gap-2.5 rounded-xl px-3 py-2.5 transition hover:bg-white/70"
                        >
                          <span className="grid size-6 shrink-0 place-items-center rounded-full bg-mint-500/15 text-mint-600">
                            <Bell size={12} />
                          </span>
                          <span className="text-[13px] text-ink-600">
                            {unreadChats.length} conversation
                            {unreadChats.length === 1 ? '' : 's'} with new messages
                          </span>
                        </Link>
                      ) : null}

                      {missingPhoto.length > 0 ? (
                        <Link
                          href="/print"
                          onClick={() => setShowBell(false)}
                          className="flex items-start gap-2.5 rounded-xl px-3 py-2.5 transition hover:bg-white/70"
                        >
                          <span className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-[var(--color-status-rejected)]/15 text-[var(--color-status-rejected)]">
                            <WifiOff size={12} />
                          </span>
                          <span className="text-[13px] leading-snug text-ink-600">
                            {missingPhoto.length} approved card
                            {missingPhoto.length === 1 ? '' : 's'} have no photo and
                            cannot print
                          </span>
                        </Link>
                      ) : null}
                    </div>
                  )}
                </motion.div>
              </>
            ) : null}
          </AnimatePresence>
        </div>

        {/* Account */}
        <div className="relative">
          <button
            type="button"
            onClick={() => {
              setShowMenu((v) => !v);
              setShowBell(false);
            }}
            className="glass flex items-center gap-2.5 rounded-full py-1.5 pl-1.5 pr-3.5 transition hover:bg-white/80"
          >
            <span className="grid size-7 place-items-center rounded-full bg-gradient-to-br from-lilac-400 to-lilac-500 text-[11px] font-bold text-white">
              {initials}
            </span>
            <span className="hidden text-[13px] font-semibold text-ink-700 sm:block">
              {profile?.displayName || profile?.email?.split('@')[0] || 'Admin'}
            </span>
          </button>

          <AnimatePresence>
            {showMenu ? (
              <>
                <button
                  type="button"
                  aria-hidden
                  tabIndex={-1}
                  className="fixed inset-0 z-40 cursor-default"
                  onClick={() => setShowMenu(false)}
                />
                <motion.div
                  initial={{ opacity: 0, y: -8, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -8, scale: 0.97 }}
                  transition={{ duration: MOTION.normal, ease: MOTION.ease }}
                  className="glass absolute right-0 top-11 z-50 w-[248px] max-w-[calc(100vw-2rem)] overflow-hidden rounded-[var(--radius-card)] p-1.5"
                >
                  <div className="px-3 py-2.5">
                    <p className="truncate text-[13px] font-semibold text-ink-700">
                      {profile?.displayName || 'Administrator'}
                    </p>
                    <p className="truncate text-[11.5px] text-ink-400">
                      {profile?.email}
                    </p>
                  </div>
                  <div className="my-1 h-px bg-ink-400/12" />
                  <button
                    type="button"
                    onClick={() => void logOut()}
                    className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-[13px] font-medium text-[var(--color-status-rejected)] transition hover:bg-[var(--color-status-rejected)]/8"
                  >
                    <LogOut size={15} />
                    Sign out
                  </button>
                </motion.div>
              </>
            ) : null}
          </AnimatePresence>
        </div>
      </div>
    </header>
  );

  // Search on a phone: a row that expands under the header rather than a
  // field squeezed beside the title. Wrapped with the header so callers keep
  // rendering one element.
  return (
    <div>
      {header}
      <AnimatePresence initial={false}>
        {onSearch && showSearch ? (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: MOTION.normal, ease: MOTION.ease }}
            className="overflow-hidden md:hidden"
          >
            <div className="relative pb-1 pt-2.5">
              <Search
                size={15}
                className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-400"
              />
              <input
                autoFocus
                value={searchValue ?? ''}
                onChange={(e) => onSearch(e.target.value)}
                placeholder={searchPlaceholder}
                className="w-full rounded-full border border-white/70 bg-white/80 py-2.5 pl-9 pr-3.5 text-[14px] text-ink-700 outline-none backdrop-blur transition placeholder:text-ink-400/80 focus:border-mint-400 focus:bg-white"
              />
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}
