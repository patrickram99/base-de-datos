// app/api/chair/check/[clerkId]/route.ts
import { prisma } from "@/utils/db"
import { NextResponse } from "next/server"

export async function GET(request: Request, props: { params: Promise<{ clerkId: string }> }) {
  const params = await props.params;
  try {
    const chair = await prisma.chair.findUnique({
      where: {
        clerkId: params.clerkId,
      },
    })

    return NextResponse.json(!!chair)
  } catch (error) {
    console.error(error)
    return NextResponse.json(false)
  }
}