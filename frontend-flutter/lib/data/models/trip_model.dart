/// Registro de uma viagem/sessão de navegação.
class TripModel {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;

  TripModel({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
  });

  Duration get duration => endedAt.difference(startedAt);
  double get distanceKm => distanceMeters / 1000;

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: json['id'] ?? '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] ?? 0),
        endedAt: DateTime.fromMillisecondsSinceEpoch(json['endedAt'] ?? 0),
        distanceMeters: (json['distanceMeters'] ?? 0).toDouble(),
        averageSpeedKmh: (json['averageSpeedKmh'] ?? 0).toDouble(),
        maxSpeedKmh: (json['maxSpeedKmh'] ?? 0).toDouble(),
        startLat: (json['startLat'] ?? 0).toDouble(),
        startLon: (json['startLon'] ?? 0).toDouble(),
        endLat: (json['endLat'] ?? 0).toDouble(),
        endLon: (json['endLon'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'distanceMeters': distanceMeters,
        'averageSpeedKmh': averageSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'startLat': startLat,
        'startLon': startLon,
        'endLat': endLat,
        'endLon': endLon,
      };
}
