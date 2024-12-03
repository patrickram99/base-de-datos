import Image from 'next/image';
import Link from 'next/link';
import { auth } from '@clerk/nextjs/server';

const novemberImages: { [key: number]: string } = {
  7: '/jueves_7.jpg',    // November 7
  8: '/viernes_8.jpg',   // November 8
  9: '/sabado_9.jpg',    // November 9
  10: '/domingo_10.jpg', // November 10
};

export default async function Home() {
  const { userId } = await auth();
  const href = userId ? '/debate' : '/new-user';

  const today = new Date();
  const isNovember = today.getMonth() === 10; // JavaScript months are 0-based
  const date = today.getDate();
  const currentImage = isNovember && novemberImages[date] ? novemberImages[date] : null;

  return (
    <main className="flex flex-col md:flex-row min-h-screen w-full">
      {/* Image section */}
      <div className="w-full h-[60vh] md:h-screen md:w-3/4 relative bg-[#1F2B62] flex items-center justify-center">
        {currentImage ? (
          <div className="relative h-full w-full flex items-center justify-center">
            <Image
              src={currentImage}
              alt="Welcome image"
              fill={false}
              width={1200}
              height={800}
              style={{ 
                maxWidth: '100%',
                maxHeight: '100%',
                width: 'auto',
                height: 'auto',
                objectFit: 'contain'
              }}
              priority
            />
          </div>
        ) : (
          <Image
            src={'/jueves_7.jpg'}
            alt="Welcome image"
            fill={false}
            width={1200}
            height={800}
            style={{ 
              maxWidth: '100%',
              maxHeight: '100%',
              width: 'auto',
              height: 'auto',
              objectFit: 'contain'
            }}
            priority
          />
        )}
      </div>

      {/* Content section */}
      <div className="w-full md:w-1/4 flex flex-col justify-center items-center p-4 md:p-8 bg-white">
        <div className="flex flex-row justify-center items-center gap-4 mb-6 md:mb-8">
          <div className="w-24 md:w-32 relative aspect-square">
            <Image
              src="/armun.png"
              alt="Logo"
              fill
              style={{ objectFit: 'contain' }}
            />
          </div>
          <div className="w-24 md:w-32 relative aspect-square">
            <Image
              src="/logo.png"
              alt="Logo 2"
              fill
              style={{ objectFit: 'contain' }}
            />
          </div>
        </div>
        
        <p className="text-center mb-6 md:mb-8 text-gray-600 text-sm md:text-base px-4">
          Bienvenido a ARMUN 2024, la simulación de las Naciones Unidas de la Universidad La Salle
        </p>
        
        <div>
          <Link href={href}>
            <button className="bg-[#1F2B62] text-white px-6 py-2 rounded-lg hover:bg-[#059FE5] transition-colors text-sm md:text-base">
              Comenzar Debate
            </button>
          </Link>
        </div>
      </div>
    </main>
  );
}