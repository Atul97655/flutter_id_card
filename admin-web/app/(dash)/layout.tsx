'use client';

import { AuthGate } from '@/components/layout/auth-gate';
import { Sidebar } from '@/components/layout/sidebar';
import { useAuth } from '@/lib/auth-context';
import { useStore } from '@/lib/store';
import { Banner } from '@/components/ui/primitives';

/**
 * The shell every signed-in page renders inside.
 *
 * The sidebar counts come from the shared store, so a card submitted on a
 * teacher's tablet right now bumps the badge here without a refresh.
 */
export default function DashLayout({ children }: { children: React.ReactNode }) {
  return (
    <AuthGate>
      <Shell>{children}</Shell>
    </AuthGate>
  );
}

function Shell({ children }: { children: React.ReactNode }) {
  const { profile } = useAuth();
  const { entries, chats, error, indexUrl } = useStore();

  const pending = entries.filter((e) => e.approvalStatus === 'pending').length;
  const unread = chats.filter((c) => c.unreadFor.includes(profile?.uid ?? '')).length;

  return (
    <div className="flex min-h-screen">
      <Sidebar pendingCount={pending} unreadCount={unread} />

      <main className="min-w-0 flex-1 px-4 pb-10 pt-4 sm:px-5 sm:pt-5 md:px-7 md:pb-8">
        {error ? (
          <div className="mb-4">
            <Banner
              tone="error"
              title="Some data could not be loaded"
              action={
                indexUrl ? (
                  <a
                    href={indexUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="shrink-0 rounded-lg bg-white/80 px-3 py-1.5 text-[12px] font-semibold text-ink-700 transition hover:bg-white"
                  >
                    Create index
                  </a>
                ) : undefined
              }
            >
              {error}
              {indexUrl ? (
                <>
                  {' '}
                  Firestore needs a one-off index for this query — the button
                  opens the console with it pre-filled. It takes a minute to
                  build, then this page works by itself.
                </>
              ) : null}
            </Banner>
          </div>
        ) : null}

        {children}
      </main>
    </div>
  );
}
