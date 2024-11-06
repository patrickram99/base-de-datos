import Assistance from "@/components/Assistance";
import { getUserByClerkId } from "@/utils/auth";
import { prisma } from "@/utils/db";


const getDelegates = async (sesId: string) => {
  const chair = await getUserByClerkId();
  console.log(sesId);

  // First try to get attendance records
  const delegatesWithAttendance = await prisma.asistencia.findMany({
    where: { 
      sessionId: parseInt(sesId, 10),
      delegate: {
        committeeId: chair.committeeId
      }
    },
    include: {
      delegate: {
        include: {
          country: {
            select: {
              name: true,
              emoji: true
            }
          }
        }
      }
    },
    orderBy: {
      delegate: {
        name: 'asc'
      }
    }
  });

  // If no attendance records exist, get delegates directly
  if (delegatesWithAttendance.length === 0) {
    const delegates = await prisma.delegate.findMany({
      where: {
        committeeId: chair.committeeId
      },
      include: {
        country: {
          select: {
            name: true,
            emoji: true
          }
        }
      },
      orderBy: {
        name: 'asc'
      }
    });

    // Return delegates with default AUSENTE state and isRegistered flag
    return {
      delegates: delegates.map(delegate => ({
        id: delegate.id,
        name: delegate.name,
        country: delegate.country.name,
        emoji: delegate.country.emoji,
        state: 'AUSENTE'
      })),
      isRegistered: false
    };
  }

  // If attendance records exist, return those with isRegistered flag
  return {
    delegates: delegatesWithAttendance.map(attendance => ({
      id: attendance.delegate.id,
      name: attendance.delegate.name,
      country: attendance.delegate.country.name,
      emoji: attendance.delegate.country.emoji,
      state: attendance.state
    })),
    isRegistered: true
  };
};


export default async function AsistenciaPage({
  searchParams,
}: {
  searchParams: { sessionId?: string }
}) {
  // Extract sessionId directly from searchParams
  const sessionId = searchParams?.sessionId;

  console.log("SessionId:", sessionId); // Log to check the value

  // If you need sessionId as a number, you can parse it here
  const sessionIdNumber = sessionId ? parseInt(sessionId, 10) : 1;

  const del = await getDelegates(sessionIdNumber);

  return (
    <Assistance 
      delegates={del.delegates} 
      isRegistered={del.isRegistered} 
      sessionId={sessionIdNumber} 
    />
  );
}