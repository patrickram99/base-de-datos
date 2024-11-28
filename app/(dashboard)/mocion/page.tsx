import MocionClient from '@/components/MocionClient';
import { getUserByClerkId } from '@/utils/auth';
import { prisma } from '@/utils/db';

// Function to get delegates based on the chair's committeeId
const getDelegates = async () => {
  const chair = await getUserByClerkId();
  
  const delegates = await prisma.delegate.findMany({
    where: {
      committeeId: chair?.committeeId || undefined, // Defensive check in case chair is null
    },
    include: {
      country: {
        select: {
          name: true,
          emoji: true,
        },
      },
    },
    orderBy: {
      name: 'asc',
    },
  });

  return delegates;
};

// Server component
export default async function MocionPage(props: { searchParams: Promise<{ sessionId: string }> }) {
  const searchParams = await props.searchParams;
  const delegates = await getDelegates();

  // Access the sessionId from searchParams
  const sessionId = searchParams?.sessionId;

  console.log(sessionId); // This should now log the sessionId correctly

  return (
    <MocionClient 
      countries={delegates.map(d => d.country)}
      sessionId={sessionId}
    />
  );
}