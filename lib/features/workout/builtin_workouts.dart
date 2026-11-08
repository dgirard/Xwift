import '../../models/workout_plan.dart';

/// Ready-made ERG programs, expressed in % of FTP so that they fit the rider.
List<WorkoutPlan> builtinWorkouts(int ftp) {
  WorkoutInterval step(int minutes, double ftpPercent, String name) =>
      WorkoutInterval.fromFtpPercent(
        duration: Duration(minutes: minutes),
        ftpPercent: ftpPercent,
        ftp: ftp,
        name: name,
      );

  return [
    WorkoutPlan(
      id: 'builtin-endurance-45',
      name: 'Endurance 45 min',
      description: 'Rythme régulier en zone 2',
      intervals: [
        step(10, 0.55, 'Échauffement'),
        step(30, 0.68, 'Endurance'),
        step(5, 0.50, 'Retour au calme'),
      ],
    ),
    WorkoutPlan(
      id: 'builtin-ftp-builder',
      name: 'FTP Builder 41 min',
      description: '3 × 5 min au seuil',
      intervals: [
        step(10, 0.65, 'Échauffement'),
        step(5, 1.00, 'Seuil 1'),
        step(3, 0.60, 'Récupération'),
        step(5, 1.00, 'Seuil 2'),
        step(3, 0.60, 'Récupération'),
        step(5, 1.00, 'Seuil 3'),
        step(10, 0.50, 'Retour au calme'),
      ],
    ),
    WorkoutPlan(
      id: 'builtin-sweet-spot',
      name: 'Sweet spot 2 × 10 min',
      description: '2 × 10 min à 90 % de la FTP',
      intervals: [
        step(10, 0.60, 'Échauffement'),
        step(10, 0.90, 'Sweet spot 1'),
        step(5, 0.55, 'Récupération'),
        step(10, 0.90, 'Sweet spot 2'),
        step(8, 0.50, 'Retour au calme'),
      ],
    ),
  ];
}
