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
  searchParams: { [key: string]: string | undefined } // More generic typing
}

export default async function DesarrolloPage({ searchParams }: Props) {
  const delegates = await getDelegates()
  const motionParam = searchParams.motion ?? '' // Handle undefined gracefully

  return <DesarrolloClient delegates={delegates} motionParam={motionParam} />
}