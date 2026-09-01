// Ported from lib/data/deed_catalog.dart — same 32 deed types, same category assignments. The
// deeds table only stores `type`, not `category`, so this mapping is needed to build the
// category breakdown at all.

export const CATEGORIES = [
  { key: 'env', name: 'Environmental Action', icon: '🌍' },
  { key: 'animal', name: 'Animal Welfare', icon: '🐾' },
  { key: 'civic', name: 'Civic & Community', icon: '🏙️' },
  { key: 'social', name: 'Social & Human Welfare', icon: '👥' },
  { key: 'health', name: 'Health & Hygiene', icon: '🏥' },
];

export const DEED_CATALOG = {
  litter: { name: 'Clear litter', icon: '🗑️', category: 'env' },
  sweep: { name: 'Sweep a walkway', icon: '🧹', category: 'env' },
  water: { name: 'Water a plant', icon: '💧', category: 'env' },
  plantSapling: { name: 'Plant a sapling', icon: '🌱', category: 'env' },
  cleanDrain: { name: 'Clean a drain', icon: '🪣', category: 'env' },
  recycle: { name: 'Recycle waste responsibly', icon: '♻️', category: 'env' },
  greenSpace: { name: 'Create a green space', icon: '🌻', category: 'env' },
  waterCooler: { name: 'Install a water cooler', icon: '🚰', category: 'env' },
  stray: { name: 'Feed a stray', icon: '🐕', category: 'animal' },
  reportInjuredAnimal: { name: 'Report injured animal', icon: '🩺', category: 'animal' },
  waterAnimals: { name: 'Provide water for animals', icon: '💧', category: 'animal' },
  buildShelter: { name: 'Build a shelter', icon: '🏠', category: 'animal' },
  feedBirds: { name: 'Feed birds', icon: '🐦', category: 'animal' },
  neuterStray: { name: 'Get a stray neutered', icon: '🐱', category: 'animal' },
  fosterAnimal: { name: 'Foster a rescue animal', icon: '🐾', category: 'animal' },
  reportStreetlight: { name: 'Report broken streetlight', icon: '💡', category: 'civic' },
  reportPothole: { name: 'Report pothole', icon: '🕳️', category: 'civic' },
  paintBench: { name: 'Paint a public bench', icon: '🪑', category: 'civic' },
  helpCrossRoad: { name: 'Help someone cross the road', icon: '🚶', category: 'civic' },
  cleanSchool: { name: 'Clean a school area', icon: '🏫', category: 'civic' },
  cleanWorship: { name: 'Clean a mosque/church/temple', icon: '🕌', category: 'civic' },
  reportHazard: { name: 'Report a safety hazard', icon: '⚠️', category: 'civic' },
  donateSupplies: { name: 'Donate school supplies', icon: '🎒', category: 'social' },
  shareMeal: { name: 'Share a meal', icon: '🍲', category: 'social' },
  donateBooks: { name: 'Donate books', icon: '📚', category: 'social' },
  donateBlood: { name: 'Donate blood', icon: '🩸', category: 'social' },
  visitElderly: { name: 'Visit the elderly', icon: '👴', category: 'social' },
  teachSkill: { name: 'Teach a skill', icon: '🧑‍🏫', category: 'social' },
  carryBags: { name: 'Help carry heavy bags', icon: '🛒', category: 'social' },
  donateFirstAid: { name: 'Donate first aid supplies', icon: '🩹', category: 'social' },
  donateMedicines: { name: 'Donate medicines', icon: '💊', category: 'health' },
  cleanClinic: { name: 'Clean a clinic/hospital area', icon: '🧹', category: 'health' },
};
