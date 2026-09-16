import type { Metadata, Viewport } from 'next';
import './globals.css';
import { AuthProvider } from '@/lib/auth-context';
import { StoreProvider } from '@/lib/store';

export const metadata: Metadata = {
  title: 'ID entity — Admin',
  description:
    'Review, approve and print school ID cards, and message the schools that submit them.',
};

export const viewport: Viewport = {
  themeColor: '#eaf6f2',
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>
        {/* Auth wraps the store: the store's subscriptions only open once a
            verified admin session exists, so an unauthenticated visitor never
            fires a single Firestore read that the rules would refuse. */}
        <AuthProvider>
          <StoreProvider>{children}</StoreProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
