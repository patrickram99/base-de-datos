import { auth } from "@clerk/nextjs/server";
import { prisma } from "./db";
import { Prisma } from "@prisma/client";

type GetUserOptionsSelect = {
    select: Prisma.ChairSelect;
    include?: never;
};

type GetUserOptionsInclude = {
    include: Prisma.ChairInclude;
    select?: never;
};

type GetUserOptions = 
    | GetUserOptionsSelect 
    | GetUserOptionsInclude 
    | Record<string, never>;  // for empty options

export const getUserByClerkId = async (options: GetUserOptions = {}) => {
    const { userId } = await auth();

    if (!userId) {
        throw new Error("User ID is null");
    }

    return await prisma.chair.findUniqueOrThrow({
        where: {
            clerkId: userId
        },
        ...options
    });
};