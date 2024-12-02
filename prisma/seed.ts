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
