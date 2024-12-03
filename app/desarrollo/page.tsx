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
  return delegates
}

export default async function DesarrolloPage({ searchParams }: { searchParams: { motion: string } }) {
  const delegates = await getDelegates()
  const motionParam = searchParams.motion

  return <DesarrolloClient delegates={delegates} motionParam={motionParam} />
}
