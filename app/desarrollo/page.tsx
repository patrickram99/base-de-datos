import { getUserByClerkId } from '@/utils/auth'
import { prisma } from '@/utils/db'
import DesarrolloClient from '@/components/DesarrolloClient'

async function getDelegates() {
  const chair = await getUserByClerkId()
  const delegates = await prisma.delegate.findMany({
    where: {
      committeeId: chair?.committeeId || undefined,
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
  })

  // Ensure emoji is always a string
  const formattedDelegates = delegates.map(delegate => ({
    ...delegate,
    country: {
      ...delegate.country,
      emoji: delegate.country.emoji || '',
    },
  }))

  return formattedDelegates
}

interface Props {
  searchParams: { [key: string]: string | undefined }
}

export default async function DesarrolloPage({ searchParams }: Props) {
  const delegates = await getDelegates()

  // `motionParam` comes from the search parameters or defaults to an empty JSON string
  const motionParam = searchParams.motion ?? JSON.stringify({
    id: 'default-motion',
    type: 'MODERATED_CAUCUS',
    country: null,
    delegates: 0,
    timePerDelegate: { minutes: 1, seconds: 30 },
    totalTime: { minutes: 15, seconds: 0 },
    votes: 0,
    topic: 'Default Topic',
  })

  return <DesarrolloClient delegates={delegates} motionParam={encodeURIComponent(motionParam)} />
}