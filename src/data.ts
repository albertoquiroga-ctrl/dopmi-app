export type Need = {
  id: string;
  title: string;
  type: "Veterinario" | "Medicina" | "Comida" | "Otra";
  requested: number;
  funded: number;
  urgent?: boolean;
  recurring?: boolean;
  status: "active" | "funded" | "evidence" | "completed";
};

export type PetCase = {
  id: string;
  name: string;
  breed?: string;
  age: string;
  sex: "Macho" | "Hembra";
  species: "Perro" | "Gato";
  image: string;
  story: string;
  location: string;
  rescuer: string;
  distance: string;
  adoption: boolean;
  caseStatus: "draft" | "review" | "active" | "rejected" | "closed";
  health: { vaccinated: boolean; sterilized: boolean; specialCare: string };
  social: { dogs: boolean; cats: boolean; children: boolean };
  needs: Need[];
};

export const initialCases: PetCase[] = [
  {
    id: "luna",
    name: "Luna",
    breed: "Mestiza",
    age: "3 meses",
    sex: "Hembra",
    species: "Perro",
    image: "/assets/luna-card.png",
    story: "La encontraron abandonada en un parque. Es dulce, juguetona y busca una familia para siempre.",
    location: "Monterrey, MX",
    rescuer: "María R.",
    distance: "1.2 km",
    adoption: true,
    caseStatus: "active",
    health: { vaccinated: true, sterilized: false, specialCare: "Seguimiento de crecimiento" },
    social: { dogs: true, cats: true, children: true },
    needs: [
      { id: "luna-food", title: "Alimento cachorro 1.5 kg", type: "Comida", requested: 18, funded: 12, recurring: true, status: "active" },
      { id: "luna-meds", title: "Tabletas antiparasitarias", type: "Medicina", requested: 15, funded: 15, urgent: true, status: "funded" },
      { id: "luna-vet", title: "Consulta inicial", type: "Veterinario", requested: 40, funded: 25, status: "active" },
    ],
  },
  {
    id: "milo",
    name: "Milo",
    breed: "Atigrado",
    age: "2 años",
    sex: "Macho",
    species: "Gato",
    image: "/assets/milo-card.png",
    story: "Atropellado; se recupera bien gracias al apoyo de la comunidad.",
    location: "San Pedro, MX",
    rescuer: "Carlos Ruiz",
    distance: "2.1 km",
    adoption: false,
    caseStatus: "active",
    health: { vaccinated: true, sterilized: true, specialCare: "Curación diaria" },
    social: { dogs: false, cats: true, children: true },
    needs: [
      { id: "milo-med", title: "Spray para heridas", type: "Medicina", requested: 12, funded: 8, urgent: true, status: "active" },
      { id: "milo-food", title: "Pack comida húmeda x12", type: "Comida", requested: 22, funded: 22, recurring: true, status: "funded" },
      { id: "milo-vet", title: "Tratamiento de pata", type: "Veterinario", requested: 80, funded: 45, status: "active" },
    ],
  },
  {
    id: "nina",
    name: "Nina",
    breed: "Mestiza",
    age: "4 años",
    sex: "Hembra",
    species: "Perro",
    image: "/assets/nina-card.png",
    story: "Nina necesita una revisión veterinaria antes de encontrar un hogar tranquilo.",
    location: "Guadalupe, MX",
    rescuer: "Refugio Patitas",
    distance: "4.8 km",
    adoption: false,
    caseStatus: "active",
    health: { vaccinated: false, sterilized: true, specialCare: "Revisión de cadera" },
    social: { dogs: true, cats: false, children: true },
    needs: [
      { id: "nina-vet", title: "Estudios de cadera", type: "Veterinario", requested: 95, funded: 45, urgent: true, status: "active" },
    ],
  },
  {
    id: "rocky",
    name: "Rocky",
    breed: "Pastor mestizo",
    age: "4 años",
    sex: "Macho",
    species: "Perro",
    image: "/assets/rocky.png",
    story: "Rocky ya completó su tratamiento y está listo para encontrar hogar.",
    location: "Monterrey, MX",
    rescuer: "María R.",
    distance: "3.4 km",
    adoption: true,
    caseStatus: "active",
    health: { vaccinated: true, sterilized: true, specialCare: "Ninguno" },
    social: { dogs: true, cats: false, children: true },
    needs: [
      { id: "rocky-vet", title: "Veterinario", type: "Veterinario", requested: 80, funded: 80, urgent: true, status: "funded" },
    ],
  },
  {
    id: "bluh",
    name: "Bluh",
    breed: "Siamés",
    age: "4 años",
    sex: "Macho",
    species: "Gato",
    image: "/assets/milo-card.png",
    story: "Publicación sin terminar.",
    location: "Monterrey, MX",
    rescuer: "María R.",
    distance: "0 km",
    adoption: false,
    caseStatus: "draft",
    health: { vaccinated: false, sterilized: false, specialCare: "Por definir" },
    social: { dogs: true, cats: true, children: true },
    needs: [],
  },
  {
    id: "nube-review",
    name: "Nube",
    breed: "Mestiza",
    age: "8 meses",
    sex: "Hembra",
    species: "Perro",
    image: "/assets/publish-sample-pet.jpg",
    story: "Rescatada hace poco. El caso está en revisión por el equipo DopMi.",
    location: "Monterrey, MX",
    rescuer: "María R.",
    distance: "1.2 km",
    adoption: false,
    caseStatus: "review",
    health: { vaccinated: false, sterilized: false, specialCare: "En evaluación" },
    social: { dogs: true, cats: true, children: true },
    needs: [
      { id: "nube-med", title: "Medicina", type: "Medicina", requested: 320, funded: 0, urgent: false, status: "active" },
    ],
  },
  {
    id: "toby-case",
    name: "Toby",
    breed: "Mestizo",
    age: "1 año",
    sex: "Macho",
    species: "Perro",
    image: "/assets/toby.png",
    story: "Necesita cirugía de emergencia tras un accidente.",
    location: "Monterrey, MX",
    rescuer: "María R.",
    distance: "2.4 km",
    adoption: false,
    caseStatus: "rejected",
    health: { vaccinated: true, sterilized: false, specialCare: "Cirugía pendiente" },
    social: { dogs: true, cats: true, children: true },
    needs: [
      { id: "toby-vet", title: "Cirugía de emergencia", type: "Veterinario", requested: 240, funded: 0, urgent: true, status: "active" },
    ],
  },
];

export const adoptionPets = [
  {
    id: "rocky",
    name: "Rocky",
    sex: "Macho" as PetCase["sex"],
    type: "Perro" as const,
    image: "/assets/rocky.png",
    story: "Rescatado de la calle el mes pasado. Muy amistoso y listo para encontrar hogar.",
    distance: "3.4 km",
    rescuer: "Patricia V.",
    location: "Monterrey, MX",
    verified: true,
    health: { vaccinated: true, sterilized: true, specialCare: false },
    social: { dogs: true, cats: false, children: true },
    journey: [
      {
        id: "r1",
        when: "Hace 3 días",
        tag: "Recuperación",
        text: "Ya camina con más energía y busca cariño a cada rato.",
        thanks: "Gracias a Ana P.",
        thanksInitial: "A",
        need: "Consulta de seguimiento · $40",
      },
    ],
  },
  {
    id: "toby",
    name: "Toby",
    sex: "Macho" as PetCase["sex"],
    type: "Perro" as const,
    image: "/assets/toby.png",
    story: "Entregado por su familia. Sano, tranquilo y listo para adopción.",
    distance: "6.2 km",
    rescuer: "Diego F.",
    location: "Querétaro, MX",
    verified: true,
    health: { vaccinated: true, sterilized: false, specialCare: false },
    social: { dogs: true, cats: true, children: true },
    journey: [
      {
        id: "t1",
        when: "Hace 1 semana",
        tag: "Recuperación",
        text: "Primer grooming: se ve como otro perrito.",
        thanks: "Gracias a Marta J.",
        thanksInitial: "M",
        need: "Alimento premium adulto · $28",
      },
    ],
  },
];

export type Rescuer = {
  name: string;
  city: string;
  bio: string;
  verified: boolean;
  publishedCases: number;
  social: { instagram: string; facebook: string };
};

export const rescuers: Rescuer[] = [
  {
    name: "Diego F.",
    city: "Querétaro, MX",
    bio: "Rescata perros entregados por familias y los prepara para adopción responsable.",
    verified: true,
    publishedCases: 1,
    social: { instagram: "@diego.patitas", facebook: "Diego F Rescates" },
  },
  {
    name: "María R.",
    city: "Monterrey, MX",
    bio: "Rescata perritos de calle desde 2019. Trabaja con una clínica veterinaria aliada en Monterrey.",
    verified: true,
    publishedCases: 1,
    social: { instagram: "@maria.rescata", facebook: "Maria Rescata" },
  },
  {
    name: "Carlos Ruiz",
    city: "San Pedro, MX",
    bio: "Enfocado en gatos heridos. Colabora con el Centro de Bienestar Animal San Pedro.",
    verified: true,
    publishedCases: 1,
    social: { instagram: "@carlos.patitas", facebook: "Carlos Ruiz" },
  },
  {
    name: "Patricia V.",
    city: "CDMX, MX",
    bio: "Casa hogar temporal para perros medianos y grandes en la Ciudad de México.",
    verified: true,
    publishedCases: 1,
    social: { instagram: "@patricia.hogar", facebook: "Patricia V." },
  },
  {
    name: "Refugio Patitas",
    city: "Guadalupe, MX",
    bio: "Refugio comunitario con 12 años apoyando animales en situación de calle.",
    verified: false,
    publishedCases: 1,
    social: { instagram: "@refugiopatitas", facebook: "Refugio Patitas" },
  },
  {
    name: "Diego F.",
    city: "Monterrey, MX",
    bio: "Voluntario de rescate y transporte de mascotas hacia sus familias adoptivas.",
    verified: true,
    publishedCases: 1,
    social: { instagram: "@diego.rescate", facebook: "Diego F." },
  },
];

export const rescuerAccount = {
  name: "María Rescatista",
  email: "maria@rescatista.com",
  phone: "+52 55 1234 5678",
  address: "Calle Reforma 123, Col. Centro, Ciudad de México, CDMX",
  description:
    "Refugio dedicado al rescate y rehabilitación de animales en situación de calle. Trabajamos con amor y compromiso para darles una segunda oportunidad.",
  instagram: "@maria.rescata",
  facebook: "Maria Rescatista",
  clabe: "012345678901234567",
};

export type NotificationKind = "message" | "donation" | "case" | "pet";

export type Notification = {
  id: string;
  kind: NotificationKind;
  title: string;
  body: string;
  time: string;
  target: string;
  read: boolean;
};

export const initialNotifications: Notification[] = [
  {
    id: "n-guardian",
    kind: "donation",
    title: "Ya eres Guardián",
    body: "Tu aportación mensual es de $50 MXN.",
    time: "Ahora",
    target: "/impact",
    read: false,
  },
  {
    id: "n-donation",
    kind: "donation",
    title: "Donación enviada exitosamente",
    body: "Tu aportación de $120 MXN a Luna ya aparece en el caso.",
    time: "Hace 1 h",
    target: "/case/luna",
    read: false,
  },
  {
    id: "n1",
    kind: "message",
    title: "Nuevo mensaje de Rescatista",
    body: "María te respondió sobre el caso de Luna.",
    time: "Hace 5 min",
    target: "/messages/luna",
    read: false,
  },
  {
    id: "n2",
    kind: "case",
    title: "Actualización del caso",
    body: "El rescatista subió nueva evidencia del apoyo recibido.",
    time: "Ayer",
    target: "/case/luna",
    read: false,
  },
  {
    id: "n3",
    kind: "pet",
    title: "Nueva mascota en adopción",
    body: "Hay una nueva mascota cerca de tu zona.",
    time: "Hace 2 días",
    target: "/adoption",
    read: true,
  },
];

export type LogEntry = {
  id: string;
  date: string;
  caseId: string;
  caseName: string;
  concept: string;
  amount: string;
  status: "completada" | "activa";
};

export const donationLog: LogEntry[] = [
  { id: "l1", date: "29 abr", caseId: "milo", caseName: "Max", concept: "Comida", amount: "$100", status: "completada" },
  { id: "l2", date: "25 abr", caseId: "luna", caseName: "Luna", concept: "Medicina", amount: "$120", status: "completada" },
  { id: "l3", date: "20 abr", caseId: "nina", caseName: "Rocky", concept: "Apadrinamiento mensual", amount: "$10/mes", status: "activa" },
  { id: "l4", date: "15 abr", caseId: "milo", caseName: "Milo", concept: "Tratamiento veterinario", amount: "$25", status: "completada" },
  { id: "l5", date: "10 abr", caseId: "nina", caseName: "Nina", concept: "Comida", amount: "$15", status: "completada" },
];

export type SubscriptionPlan = { id: string; name: string; amount: number; recommended?: boolean };

export const subscriptionPlans: SubscriptionPlan[] = [
  { id: "basico", name: "Community Member Básico", amount: 50 },
  { id: "plus", name: "Community Member Plus", amount: 200, recommended: true },
  { id: "pro", name: "Community Member Pro", amount: 500 },
];

export const paymentHistory = [
  { id: "p1", date: "3 junio 2026", method: "Visa 4242", amount: "$50.00 MXN" },
  { id: "p2", date: "3 mayo 2026", method: "Apple Pay", amount: "$50.00 MXN" },
  { id: "p3", date: "3 abril 2026", method: "Visa 4242", amount: "$50.00 MXN" },
];

export const savedCards = [
  { id: "visa", brand: "Visa", digits: "4242", default: true },
  { id: "mastercard", brand: "Mastercard", digits: "1881", default: false },
];

export type FaqItem = { q: string; a: string };

export const donorFaqs: FaqItem[] = [
  {
    q: "¿Cómo funciona mi suscripción mensual?",
    a: "Cada mes se cobra el monto que elegiste y se reparte entre los casos activos que más lo necesitan. Puedes cambiar la cantidad o cancelarla desde Suscripción y pagos.",
  },
  {
    q: "¿Cómo sé que mi donación se usó correctamente?",
    a: "El rescatista sube evidencia (fotos y comprobantes) por cada necesidad cubierta. Te avisamos con una notificación cuando hay una nueva.",
  },
  {
    q: "¿Dónde veo las evidencias de los casos que apoyé?",
    a: "En Tu Impacto y en el detalle de cada caso encontrarás la evidencia publicada por el rescatista.",
  },
  {
    q: "¿Cómo puedo cancelar mi suscripción?",
    a: "Entra a Perfil › Configuración › Suscripción y pagos y toca Cancelar suscripción. Puedes volver a suscribirte cuando quieras.",
  },
  {
    q: "¿Cómo guardo una mascota o caso?",
    a: "Usa el marcador en la tarjeta o en el detalle. Lo encontrarás después en Perfil › Mascotas guardadas.",
  },
];

export const rescuerFaqs: FaqItem[] = [
  {
    q: "¿Cómo verifico mi cuenta?",
    a: "Sube una identificación oficial, un comprobante de domicilio y tus datos bancarios. La revisión tarda hasta 48 horas.",
  },
  {
    q: "¿Por qué necesito verificarme para recibir donaciones?",
    a: "La verificación protege a la comunidad: garantiza que los fondos llegan a una persona real y responsable del caso.",
  },
  {
    q: "¿Cómo publico una mascota en adopción?",
    a: "Desde Publicar elige Dar en adopción y completa los cuatro pasos: fotos, información básica, necesidades y revisión.",
  },
  {
    q: "¿Cómo publico un caso para recibir donaciones?",
    a: "Desde Publicar elige Recibir donaciones y define cada necesidad con su monto objetivo.",
  },
  {
    q: "¿Cómo subo evidencia de gastos?",
    a: "En el detalle del caso, toca la necesidad cubierta y sube la foto del comprobante. Los donantes reciben una notificación.",
  },
];
