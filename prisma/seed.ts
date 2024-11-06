import { PrismaClient, Level, Role, SessionStatus } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const committees = [
    {
      name: "TEST",
      topic:
        "Secretariado de prueba",
      level: Level.MIXED,
    },
    {
      name: "ACNUR",
      topic:
        "Acceso equitativo en la atención médica y tratamiento del enfermedades controladas de refugiados en situaciones de desplazamiento",
      level: Level.ESCOLAR,
    },
    {
      name: "CONSEJO DE SEGURIDAD",
      topic: "La situación en Haití",
      level: Level.ESCOLAR,
    },
    {
      name: "DISEC",
      topic:
        "La utilización del espacio ultra terrestre; gestión de desastres espaciales y prevención ante el manejo de los desechos espaciales",
      level: Level.ESCOLAR,
    },
    {
      name: "ONU MUJERES",
      topic:
        "El desarrollo de los derechos civiles, sociales y políticos de las mujeres con diversidades funcionales",
      level: Level.ESCOLAR,
    },
    {
      name: "OMS",
      topic:
        "El estigma de la crisis de salud mental en la población joven económicamente activa en los paises de Asia",
      level: Level.ESCOLAR,
    },
    {
      name: "OIEA",
      topic: "Gestión en el proceso de transición energética sostenible",
      level: Level.ESCOLAR,
    },
    { name: "AFRICAN UNION", topic: "Neocolonial Legacy", level: Level.ESCOLAR },
    {
      name: "UNODC",
      topic:
        "Impacto del Crimen Organizado y el Lavado de  activos como financiación del terrorismo transnacional",
      level: Level.ESCOLAR,
    },
    {
      name: "FIFA",
      topic:
        "Relaciones entre Barras Bravas y Grupos Delictivos; perspectivas de sanción administrativa ante los equipos deportivos, Controversias en la elección de sedes de torneos: criterios de selección y su impacto en el desarrollo regional",
      level: Level.ESCOLAR,
    },
    {
      name: "NAC",
      topic: "La situación de Bosnia y Herzegovina de 1995",
      level: Level.ESCOLAR,
    },
    {
      name: "OEA",
      topic: "Salvador Allende, pronóstico de un golpe organizado",
      level: Level.ESCOLAR,
    },
    {
      name: "CRISIS HISTÓRICA FRANCIA",
      topic: "Guerras Napoleónicas, el imperio francés",
      level: Level.ESCOLAR,
    },
    {
      name: "CRISIS HISTÓRICA EUROPA",
      topic: "Guerras Napoleónicas, Europa",
      level: Level.ESCOLAR,
    },
    {
      name: "CRISIS FUTURISTA",
      topic:
        "Desastre post apocalíptico; un panorama a partir de la saga de Fallout",
      level: Level.ESCOLAR,
    },
    {
      name: "CRISIS FANTÁSTICA",
      topic: "El comienzo de una leyenda, ARCANE",
      level: Level.ESCOLAR,
    },
    {
      name: "SOCHUM",
      topic:
        "Religious discrimination and freedom of worship: protecting the rights of religious minorities",
      level: Level.ESCOLAR,
    },
    {
      name: "UNESCO",
      topic:
        "Protección integral de la Libertad de Expresión y los Periodistas en zonas de exclusión y conflictos armados",
      level: Level.UNIVERSITARIO,
    },
    {
      name: "CCPCJ",
      topic:
        "Revisión del marco legal ante la represión policial frente a las manifestaciones políticas",
      level: Level.UNIVERSITARIO,
    },
    {
      name: "CDH",
      topic:
        "Crímenes de Lesa Humanidad en conflictos políticos en América Latina",
      level: Level.UNIVERSITARIO,
    },
    {
      name: "UNICEF",
      topic:
        "Programs for protecting families in poverty: prevention of abandonment and support for home stability",
      level: Level.UNIVERSITARIO,
    },
    { name: "PRENSA", topic: "", level: Level.UNIVERSITARIO },
    {
      name: "CRISIS HISTÓRICA",
      topic:
        "El horizonte de un sueño roto dada en 1963: La tragedia de Dallas",
      level: Level.UNIVERSITARIO,
    },
    {
      name: "ASAMBLEA GENERAL",
      topic:
        "Rasgos punitivos como parte de la soberania nacional, en aplicación del control social y relaciones exteriores.",
      level: Level.MIXED,
    },
  ];

  // const chairs = [
  //   { name: "SILVIO SOLORZANO", role: Role.DIRECTOR, committeeId: 1 },
  //   { name: "ZAFIRO ZAPANA", role: Role.DIRECTORA_ADJUNTA, committeeId: 1 },
  //   { name: "DIANA MAMANI", role: Role.MODERADORA, committeeId: 1 },

  //   { name: "ALVARO TAPIA", role: Role.DIRECTOR, committeeId: 2 },
  //   { name: "DANIELA ENDO", role: Role.DIRECTORA_ADJUNTA, committeeId: 2 },
  //   { name: "SAID SALAS", role: Role.MODERADOR, committeeId: 2 },

  //   { name: "MARCELO CARPIO", role: Role.DIRECTOR, committeeId: 3 },
  //   { name: "MARCELLO RODRIGUEZ", role: Role.DIRECTOR_ADJUNTO, committeeId: 3 },
  //   { name: "BRUNO RODRIGUEZ", role: Role.MODERADOR, committeeId: 3 },

  //   {
  //     name: "ALEJANDRA ESCOBEDO",
  //     role: Role.DIRECTORA_ADJUNTA,
  //     committeeId: 4,
  //   },
  //   { name: "LIZBETH LAROTA", role: Role.DIRECTORA_ADJUNTA, committeeId: 4 },
  //   { name: "JESSICA HUARCA", role: Role.MODERADORA, committeeId: 4 },

  //   { name: "GABRIELA VARGAS", role: Role.DIRECTORA, committeeId: 5 },
  //   { name: "GABRIEL BACA", role: Role.DIRECTOR_ADJUNTO, committeeId: 5 },
  //   { name: "JULIO BARREDA", role: Role.MODERADOR, committeeId: 5 },

  //   { name: "SHARON SOLIS", role: Role.DIRECTORA, committeeId: 6 },
  //   { name: "MASSIEL FARFAN", role: Role.DIRECTORA_ADJUNTA, committeeId: 6 },
  //   { name: "ALEXIA PAZ", role: Role.MODERADORA, committeeId: 6 },

  //   { name: "ALEJANDRO SANCHEZ", role: Role.DIRECTOR, committeeId: 7 },
  //   { name: "VALERIA MOROTE", role: Role.DIRECTORA_ADJUNTA, committeeId: 7 },
  //   { name: "ALFREDO ESCAJADILLO", role: Role.MODERADOR, committeeId: 7 },

  //   { name: "SOPHIA VALDIVIA", role: Role.DIRECTORA, committeeId: 8 },
  //   { name: "GABRIEL CHAVEZ", role: Role.DIRECTOR_ADJUNTO, committeeId: 8 },
  //   { name: "JOSUE RODRIGUEZ", role: Role.MODERADOR, committeeId: 8 },

  //   { name: "FABIAN GALDOS", role: Role.DIRECTOR, committeeId: 9 },
  //   { name: "VALERIA VILLAROEL", role: Role.DIRECTORA_ADJUNTA, committeeId: 9 },
  //   { name: "ALESSA SOZA", role: Role.MODERADORA, committeeId: 9 },

  //   { name: "IGNACIO TEJADA", role: Role.DIRECTOR, committeeId: 10 },
  //   { name: "MACARENA POLO", role: Role.DIRECTORA_ADJUNTA, committeeId: 10 },
  //   { name: "RODRIGO LLERENA", role: Role.MODERADOR, committeeId: 10 },

  //   { name: "JOAQUIN ZARATE", role: Role.DIRECTOR, committeeId: 11 },
  //   { name: "RODRIGO CARPIO", role: Role.DIRECTOR_ADJUNTO, committeeId: 11 },
  //   { name: "DIEGO CUETO", role: Role.MODERADOR, committeeId: 11 },

  //   { name: "TATIANA ECHEVARRIA", role: Role.DIRECTORA, committeeId: 12 },
  //   {
  //     name: "JEREMIAS PEÑARANDA",
  //     role: Role.DIRECTOR_ADJUNTO,
  //     committeeId: 12,
  //   },
  //   { name: "SEBASTIAN BARREDA", role: Role.MODERADOR, committeeId: 12 },

  //   { name: "SIBONÉ DAVILA", role: Role.DIRECTORA, committeeId: 13 },
  //   { name: "GABRIEL GALVEZ", role: Role.DIRECTOR_ADJUNTO, committeeId: 13 },
  //   { name: "BRAYAN PARISACA", role: Role.MODERADOR, committeeId: 13 },

  //   { name: "SANTIAGO HUACO", role: Role.DIRECTOR, committeeId: 14 },
  //   { name: "MARIANA OTERO", role: Role.DIRECTORA_ADJUNTA, committeeId: 14 },
  //   { name: "CAMILA GOMEZ", role: Role.MODERADORA, committeeId: 14 },

  //   { name: "BRUNO LUNA", role: Role.DIRECTOR, committeeId: 15 },
  //   { name: "DANIELA LOPEZ", role: Role.DIRECTORA_ADJUNTA, committeeId: 15 },
  //   { name: "DANILO LAZO", role: Role.MODERADOR, committeeId: 15 },

  //   { name: "CLAUDIA DAVILA", role: Role.DIRECTORA, committeeId: 16 },
  //   { name: "LUCIANA PALACIOS", role: Role.DIRECTORA_ADJUNTA, committeeId: 16 },
  //   { name: "SANTIAGO MENDEZ", role: Role.MODERADOR, committeeId: 16 },

  //   { name: "LUCIANA RODRIGUEZ", role: Role.DIRECTORA, committeeId: 17 },
  //   { name: "VALERIA MONROY", role: Role.DIRECTORA_ADJUNTA, committeeId: 17 },
  //   { name: "ARIANA TAPIA", role: Role.MODERADORA, committeeId: 17 },

  //   { name: "ANA BELÉN AMPUERO", role: Role.DIRECTORA, committeeId: 18 },
  //   { name: "LUCAS PILCO", role: Role.DIRECTOR_ADJUNTO, committeeId: 18 },
  //   { name: "ANGELY CONDORENA", role: Role.MODERADORA, committeeId: 18 },

  //   { name: "ANALU AMÉZQUITA", role: Role.DIRECTORA, committeeId: 19 },
  //   { name: "LUIS VILCHEZ", role: Role.DIRECTOR_ADJUNTO, committeeId: 19 },
  //   { name: "ANGHELA RUIZ", role: Role.MODERADORA, committeeId: 19 },

  //   { name: "ADRIANA PICKMANN", role: Role.DIRECTORA, committeeId: 20 },
  //   { name: "SOFIA PERALTA", role: Role.DIRECTORA_ADJUNTA, committeeId: 20 },
  //   { name: "FARID BELLIDO", role: Role.MODERADOR, committeeId: 20 },

  //   { name: "ALEJANDRO CARDENAS", role: Role.DIRECTOR, committeeId: 21 },
  //   { name: "MAJO NÚÑEZ", role: Role.DIRECTORA_ADJUNTA, committeeId: 21 },
  //   { name: "OLGA ARENAS", role: Role.MODERADORA, committeeId: 21 },

  //   { name: "MAXIME KIPS", role: Role.DIRECTOR, committeeId: 22 },
  //   { name: "PIERO ROJAS", role: Role.DIRECTOR_ADJUNTO, committeeId: 22 },
  //   { name: "MARIA SALAZAR", role: Role.MODERADORA, committeeId: 22 },

  //   { name: "KEVIN BARRETO", role: Role.DIRECTOR, committeeId: 23 },
  //   { name: "ATILIO MONTALVO", role: Role.DIRECTOR_ADJUNTO, committeeId: 23 },
  //   { name: "LUCIANA CORNEJO", role: Role.MODERADORA, committeeId: 23 },

  //   { name: "OMAR MUJICA", role: Role.CRISIS_ROOM, committeeId: 12 },
  // ];

  const sessions = [
    {
      date: new Date("2024-11-08"),
      startTime: new Date("2024-11-08T17:00:00"),
      endTime: new Date("2024-11-08T18:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-08"),
      startTime: new Date("2024-11-08T18:15:00"),
      endTime: new Date("2024-11-08T19:30:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-09"),
      startTime: new Date("2024-11-09T08:30:00"),
      endTime: new Date("2024-11-09T10:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-09"),
      startTime: new Date("2024-11-09T10:30:00"),
      endTime: new Date("2024-11-09T13:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-09"),
      startTime: new Date("2024-11-09T14:30:00"),
      endTime: new Date("2024-11-09T17:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-09"),
      startTime: new Date("2024-11-09T17:30:00"),
      endTime: new Date("2024-11-09T19:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-10"),
      startTime: new Date("2024-11-10T08:30:00"),
      endTime: new Date("2024-11-10T10:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-10"),
      startTime: new Date("2024-11-10T10:30:00"),
      endTime: new Date("2024-11-10T12:00:00"),
      status: SessionStatus.SCHEDULED,
    },
    {
      date: new Date("2024-11-10"),
      startTime: new Date("2024-11-10T14:30:00"),
      endTime: new Date("2024-11-10T16:30:00"),
      status: SessionStatus.SCHEDULED,
    },
  ];

  for (const committee of committees) {
    await prisma.committee.create({
      data: committee,
    });
  }

  // for (const chair of chairs) {
  //   await prisma.chair.create({
  //     data: chair,
  //   });
  // }

  for (const session of sessions) {
    await prisma.session.create({
      data: session,
    });
  }

  console.log("Seed data inserted successfully.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
