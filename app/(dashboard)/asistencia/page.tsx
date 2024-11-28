import Assistance from "@/components/Assistance";
import { getUserByClerkId } from "@/utils/auth";
import { prisma } from "@/utils/db";


const getDelegates = async (sesId: number) => {
  const chair = await getUserByClerkId();
  console.log(sesId);

  // First try to get attendance records
  const delegatesWithAttendance = await prisma.asistencia.findMany({
    where: { 
      sessionId: sesId,
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


export default async function AsistenciaPage(
  props: {
    searchParams: Promise<{ sessionId?: string }>
  }
) {
  const searchParams = await props.searchParams;
  // Parse sessionId to a number, defaulting to 1 if not provided or invalid
  const sessionId = searchParams.sessionId ? parseInt(searchParams.sessionId, 10) : 1;

  // Now sessionId is already a number, so we can pass it directly
  const del = await getDelegates(sessionId);

  return (
    <Assistance 
      delegates={del.delegates} 
      isRegistered={del.isRegistered} 
      sessionId={sessionId} 
    />
  );
}