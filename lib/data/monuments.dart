// Ported from MONUMENTS in ACHA_KARO_FINALIZED.html — the scrolling marquee behind the login
// screen's logo.

class Monument {
  final String icon;
  final String name;
  const Monument({required this.icon, required this.name});
}

const List<Monument> monuments = [
  Monument(icon: '🕌', name: 'Badshahi Mosque'),
  Monument(icon: '🗼', name: 'Minar-e-Pakistan'),
  Monument(icon: '🕌', name: 'Faisal Mosque'),
  Monument(icon: '⛰️', name: 'K2'),
  Monument(icon: '🏛️', name: 'Mohenjo-daro'),
  Monument(icon: '🏰', name: 'Lahore Fort'),
  Monument(icon: '🏯', name: 'Rohtas Fort'),
  Monument(icon: '🌉', name: 'Ayub Bridge'),
  Monument(icon: '🕌', name: 'Mazar-e-Quaid'),
];
