import { redirect } from 'next/navigation';

/** The panel has one home: the dashboard. */
export default function Home() {
  redirect('/dashboard');
}
