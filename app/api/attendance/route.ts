// app/api/attendance/route.js
import { prisma } from "@/utils/db";
import { NextResponse } from "next/server";

export async function POST(req) {
  try {
    const { attendanceRecords } = await req.json();

    // Create all attendance records in a single transaction
    const result = await prisma.$transaction(
      attendanceRecords.map((record) =>
        prisma.asistencia.create({
          data: {
            delegateId: record.delegateId,
            sessionId: record.sessionId,
            state: record.state,
          },
        })
      )
    );

    return NextResponse.json({ success: true, data: result });
  } catch (error) {
    console.error('Error saving attendance:', error);
    return NextResponse.json(
      { success: false, error: 'Failed to save attendance' },
      { status: 500 }
    );
  }
}