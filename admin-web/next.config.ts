import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  /**
   * The panel has one home. Doing this at the edge rather than with a
   * `redirect()` inside a server component means a real HTTP 308 with no React
   * render at all - one less thing to go wrong, and no error-boundary HTML
   * shipped alongside the redirect.
   */
  async redirects() {
    return [{ source: '/', destination: '/dashboard', permanent: false }];
  },
};

export default nextConfig;
