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
      type: json['type'] ?? json['alert_type'] ?? 'texto_livre',
      message: json['message'],
      maxHeight: _toDouble(json['maxHeight'] ?? json['max_height_allowed']),
      maxWeight: _toDouble(json['maxWeight'] ?? json['max_weight_allowed']),
      latitude: _toDouble(json['latitude'] ?? json['lat']) ?? 0,
      longitude: _toDouble(json['longitude'] ?? json['lon']) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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
