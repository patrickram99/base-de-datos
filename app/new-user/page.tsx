import { prisma } from "@/utils/db";
import { currentUser } from "@clerk/nextjs/server";
import { Role } from "@prisma/client";
import { redirect } from 'next/navigation'

const createNewUser = async () => {
    const chair  = await currentUser()
    const match = await prisma.chair.findUnique({
        where: {
            clerkId: chair?.id
        }
    })

    if (!match) {
        await prisma.chair.create({
            data: {
                clerkId: chair?.id ?? '',
                email: chair?.emailAddresses[0].emailAddress ?? '',
                name: chair?.fullName ?? '',
                role: Role.DIRECTOR,
                committeeId: 2
            }
        })
    }

    redirect('/debate')
}

const NewUser = async () => {
    await createNewUser()
    return (
        <div>
            <h1>New User</h1>
        </div>
    );
}

export default NewUser; 