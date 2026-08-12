// Ported from PAST_WINNERS in ACHA_KARO_FINALIZED.html.

class PastWinner {
  final int week;
  final String name;
  final String city;
  final int points;
  const PastWinner({required this.week, required this.name, required this.city, required this.points});
}

const List<PastWinner> pastWinners = [
  PastWinner(week: 31, name: 'Hira Malik', city: 'Faisalabad', points: 905),
  PastWinner(week: 30, name: 'Ahsan Qureshi', city: 'Peshawar', points: 880),
  PastWinner(week: 29, name: 'Sana Rizvi', city: 'Karachi', points: 860),
  PastWinner(week: 28, name: 'Usman Tariq', city: 'Lahore', points: 845),
];
