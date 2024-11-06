import Image from 'next/image';
import Link from 'next/link';
import { unstable_cache } from 'next/cache';
import { prisma } from '@/utils/db';
import { Card, CardContent, CardFooter } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

// Load environment variable
const disableTimeValidation = process.env.DISABLE_TIME_VALIDATION === 'true';

// Function to format date to readable string
function formatDate(date: Date) {
  const days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 
                 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  
  const utcDate = new Date(date.getTime() + date.getTimezoneOffset() * 60000);
  var str = `${days[utcDate.getUTCDay()]}, ${utcDate.getUTCDate()} de ${months[utcDate.getUTCMonth()]} ${utcDate.getUTCFullYear()}`;
  return str;
}

// Function to format time
function formatTime(date: Date) {
  return date.toLocaleTimeString('es-ES', { 
    hour: '2-digit', 
    minute: '2-digit',
    hour12: false 
  });
}

// Function to check if current time is within session time range with 15-minute tolerance
function isWithinTimeRange(startTime: Date, endTime: Date) {
    const now = new Date();
    const startWithTolerance = new Date(new Date(startTime).getTime() - 15 * 60 * 1000); // 15 minutes before startTime
    const endWithTolerance = new Date(new Date(endTime).getTime() + 15 * 60 * 1000);     // 15 minutes after endTime
  
    return now >= startWithTolerance && now <= endWithTolerance;
  }
  

// Function to fetch and cache sessions
async function getSessions() {
  return unstable_cache(
    async () => {
      const sessions = await prisma.session.findMany({
        orderBy: {
          date: 'asc',
        },
      });
      return sessions;
    },
    ['sessions'],
    {
      revalidate: 3600, // Cache for 1 hour
      tags: ['sessions'],
    }
  )();
}

// Group sessions by day
function groupSessionsByDay(sessions: any) {
  const grouped = sessions.reduce((acc: any, session: any) => {
    const day = new Date(session.date).toISOString().split('T')[0];
    if (!acc[day]) {
      acc[day] = [];
    }
    acc[day].push(session);
    return acc;
  }, {});
  return grouped;
}

export default async function DebatePage() {
  const sessions = await getSessions();
  const groupedSessions = groupSessionsByDay(sessions);

  return (
    <div className="min-h-screen bg-slate-50">
      {/* Header Section */}
      <div className="flex flex-col items-center py-8 space-y-4">
      <Image
            src="/armun.png"
            alt="ARMUN logo"
            width={0}
            height={0}
            sizes="100vw"
            style={{ width: "10%", height: "auto" }} // optional
          />
        <h1 className="text-3xl font-bold text-slate-900">
          Sesiones de Debate
        </h1>
      </div>

      {/* Sessions Grid */}
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="space-y-8">
          {Object.keys(groupedSessions).map((day) => (
            <div key={day} className="space-y-4">
              <h2 className="text-xl font-semibold text-slate-900 mb-4">
                {formatDate(new Date(day))}
              </h2>
              <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
                {groupedSessions[day].map((session: any) => {
                  const canStartSession =
                    disableTimeValidation || isWithinTimeRange(session.startTime, session.endTime);

                  return (
                    <Card key={session.id} className="flex flex-col">
                      <CardContent className="flex-grow p-6">
                        <h3 className="text-xl font-semibold text-slate-900 mb-4">
                          Sesión {session.id}
                        </h3>
                        <div className="space-y-2">
                          <div className="flex items-center text-slate-600">
                            <span className="font-medium text-slate-700">Inicio:</span>
                            <span className="ml-2">
                              {formatTime(new Date(session.startTime))}
                            </span>
                          </div>
                          {session.endTime && (
                            <div className="flex items-center text-slate-600">
                              <span className="font-medium text-slate-700">Fin:</span>
                              <span className="ml-2">
                                {formatTime(new Date(session.endTime))}
                              </span>
                            </div>
                          )}
                        </div>
                      </CardContent>
                      <CardFooter className="p-6 pt-0">
                        <Link href={`/mocion?sessionId=${session.id}`} className="w-full">
                          <Button
                            className="w-full"
                            size="lg"
                            disabled={!canStartSession}
                          >
                            Iniciar
                          </Button>
                        </Link>
                      </CardFooter>
                    </Card>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
