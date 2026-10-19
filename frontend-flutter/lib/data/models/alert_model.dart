class AlertModel {
  final String id;
  final String driverId;
  final String type;
  final String? message;
  final double? maxHeight;
  final double? maxWeight;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  AlertModel({
    required this.id,
    required this.driverId,
    required this.type,
    this.message,
    this.maxHeight,
    this.maxWeight,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] ?? '',
      driverId: json['driverId'] ?? json['driver_id'] ?? '',
      type: json['type'] ?? 'texto_livre',
      message: json['message'],
      maxHeight: json['maxHeight'] != null ? (json['maxHeight'] as num).toDouble() : null,
      maxWeight: json['maxWeight'] != null ? (json['maxWeight'] as num).toDouble() : null,
      latitude: (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? json['lon'] ?? 0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverId': driverId,
        'type': type,
        'message': message,
        'maxHeight': maxHeight,
        'maxWeight': maxWeight,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': createdAt.millisecondsSinceEpoch,
      };
}
