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

// @ts-ignore
export default async function DesarrolloPage({ searchParams }: { searchParams: { motion: string } }) {
  const delegates = await getDelegates()
  const motionParam = searchParams.motion

  return <DesarrolloClient delegates={delegates} motionParam={motionParam} />
}