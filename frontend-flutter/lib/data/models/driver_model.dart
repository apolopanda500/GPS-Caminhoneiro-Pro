class DriverModel {
  final String driverId;
  final String email;
  final String? name;
  final bool isPremium;
  final double truckHeight;
  final double truckWeight;
  final int axleCount;
  final bool hazmat;
  final String? avatarUrl;
  final String? truckPhotoUrl;
  final String? truckModel;
  final String? cargoType;
  final String truckIcon;

  /// 'motorista' ou 'ajudante'.
  final String role;

  /// Tipo de ajuda do ajudante (mecanica, carga, rota, etc).
  final String? helpType;

  /// Empresa do motorista (endereco base).
  final String? companyName;
  final double? companyLat;
  final double? companyLon;

  DriverModel({
    required this.driverId,
    required this.email,
    this.name,
    this.isPremium = false,
    this.truckHeight = 4.40,
    this.truckWeight = 45.00,
    this.axleCount = 2,
    this.hazmat = false,
    this.avatarUrl,
    this.truckPhotoUrl,
    this.truckModel,
    this.cargoType,
    this.truckIcon = '🚚',
    this.role = 'motorista',
    this.helpType,
    this.companyName,
    this.companyLat,
    this.companyLon,
  });

  bool get isHelper => role == 'ajudante';

  factory DriverModel.fromJson(Map<String, dynamic> json) => DriverModel(
        driverId: json['driverId'] ?? json['driver_id'] ?? '',
        email: json['email'] ?? '',
        name: json['name'],
        isPremium: json['isPremium'] ?? json['is_premium'] ?? false,
        truckHeight: (json['truckHeight'] ?? json['truck_height'] ?? 4.40).toDouble(),
        truckWeight: (json['truckWeight'] ?? json['truck_weight'] ?? 45.00).toDouble(),
        axleCount: json['axleCount'] ?? json['axle_count'] ?? 2,
        hazmat: json['hazmat'] ?? false,
        avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
        truckPhotoUrl: json['truckPhotoUrl'] ?? json['truck_photo_url'],
        truckModel: json['truckModel'] ?? json['truck_model'],
        cargoType: json['cargoType'] ?? json['cargo_type'],
        truckIcon: (json['truckIcon'] ?? json['truck_icon'] ?? '🚚').toString(),
        role: (json['role'] ?? 'motorista').toString(),
        helpType: json['helpType'] ?? json['help_type'],
        companyName: json['companyName'] ?? json['company_name'],
        companyLat: _toDouble(json['companyLat'] ?? json['company_lat']),
        companyLon: _toDouble(json['companyLon'] ?? json['company_lon']),
      );

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() => {
        'driverId': driverId,
        'email': email,
        'name': name,
        'isPremium': isPremium,
        'truckHeight': truckHeight,
        'truckWeight': truckWeight,
        'axleCount': axleCount,
        'hazmat': hazmat,
        'avatarUrl': avatarUrl,
        'truckPhotoUrl': truckPhotoUrl,
        'truckModel': truckModel,
        'cargoType': cargoType,
        'truckIcon': truckIcon,
        'role': role,
        'helpType': helpType,
        'companyName': companyName,
        'companyLat': companyLat,
        'companyLon': companyLon,
      };
}
