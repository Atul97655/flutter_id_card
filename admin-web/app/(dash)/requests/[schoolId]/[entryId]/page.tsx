import { RequestDetail } from './detail';

/**
 * Next 16 hands route params as a Promise. Awaiting them in this server
 * component keeps the client component below a plain props boundary, rather
 * than every child having to unwrap a promise.
 */
export default async function Page({
  params,
}: {
  params: Promise<{ schoolId: string; entryId: string }>;
}) {
  const { schoolId, entryId } = await params;
  return <RequestDetail schoolId={schoolId} entryId={entryId} />;
}
