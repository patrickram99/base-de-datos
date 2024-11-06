// (dashboard)/layout.tsx
import DashboardLayout from "@/components/DashboardLayout";
import { getUserByClerkId } from "@/utils/auth";
import { prisma } from "@/utils/db";

const getSessionAndCommittee = async () => {
  const chair = await getUserByClerkId();

  // Fetch the committee name
  const committee = await prisma.committee.findUnique({
    where: { id: chair.committeeId },
    select: { name: true },
  });

  return {
    session: "Líderes con Impacto", // Replace with actual session data
    committeeName: committee?.name,
  };
};

export default async function Layout({ children }) {
  const { session, committeeName } = await getSessionAndCommittee();

  return (
    <DashboardLayout session={session} committee={committeeName}>
      {children}
    </DashboardLayout>
  );
}
