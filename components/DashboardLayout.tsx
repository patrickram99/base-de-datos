import Image from "next/image";
import Link from "next/link";

const DashboardLayout = ({ children, session, committee }) => {
  return (
    <div className="min-h-screen flex flex-col">
      {/* First line with logo and text */}
      <div className="w-full px-4 p-4">
        <div className="flex items-center gap-2">
          <Link href="/mocion?sessionId=1">
            <Image
              src="/armun.png"
              alt="ARMUN logo"
              width={0}
              height={0}
              sizes="100vw"
              style={{ width: "10%", height: "auto" }} // optional
            />
          </Link>
          <h1 className="font-medium text-6xl p-4">{committee}</h1>
        </div>
      </div>

      {/* Second line with centered session text */}
      <div className="w-full px-4 py-2 bg-[#1F2B62] text-white">
        <div className="text-center">
          <span>{session}</span>
        </div>
      </div>

      {/* Main content area */}
      <main className="flex-1 p-4">{children}</main>
    </div>
  );
};

export default DashboardLayout;