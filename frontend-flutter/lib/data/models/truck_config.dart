class TruckConfig {
  final String driverId;
  final double height;
  final double width;
  final double length;
  final double weight;
  final int axleCount;
  final bool hazmat;

  TruckConfig({
    required this.driverId,
    required this.height,
    required this.width,
    required this.length,
    required this.weight,
    this.axleCount = 2,
    this.hazmat = false,
  });

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'height': height,
        'width': width,
        'length': length,
        'weight': weight,
        'axleCount': axleCount,
        'hazmat': hazmat,
      };

  factory TruckConfig.fromJson(Map<String, dynamic> json) => TruckConfig(
        driverId: json['driverId'],
        height: (json['height'] ?? 4.40).toDouble(),
        width: (json['width'] ?? 2.50).toDouble(),
        length: (json['length'] ?? 13.50).toDouble(),
        weight: (json['weight'] ?? 45.00).toDouble(),
        axleCount: json['axleCount'] ?? 2,
        hazmat: json['hazmat'] ?? false,
      );
}
