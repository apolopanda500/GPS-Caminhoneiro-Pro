import 'package:gps_camioneiro_pro/core/constants/app_constants.dart';

/// Marcador personalizado colocado no mapa pelo motorista (sinal, emoji, aviso).
/// É TEMPORÁRIO: expira após [AppConstants.markerTtl] para manter o mapa limpo.
class MapMarkerModel {
  final String id;
  final String emoji;
  final String type;
  final String? label;
  final double latitude;
  final double longitude;
  final String driverId;
  final DateTime createdAt;

  MapMarkerModel({
    required this.id,
    required this.emoji,
    required this.type,
    this.label,
    required this.latitude,
    required this.longitude,
    this.driverId = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Duration get age => DateTime.now().difference(createdAt);

  bool isExpired([Duration ttl = AppConstants.markerTtl]) => age > ttl;

  factory MapMarkerModel.fromJson(Map<String, dynamic> json) => MapMarkerModel(
        id: json['id'] ?? '',
        emoji: json['emoji'] ?? '📍',
        type: json['type'] ?? 'sinal',
        label: json['label'],
        latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
        longitude: (json['longitude'] ?? json['lon'] ?? 0).toDouble(),
        driverId: json['driverId'] ?? json['driver_id'] ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'type': type,
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'driverId': driverId,
        'timestamp': createdAt.millisecondsSinceEpoch,
      };

  MapMarkerModel copyWith({String? emoji, String? type, String? label}) => MapMarkerModel(
        id: id,
        emoji: emoji ?? this.emoji,
        type: type ?? this.type,
        label: label ?? this.label,
        latitude: latitude,
        longitude: longitude,
        driverId: driverId,
        createdAt: createdAt,
      );
}
