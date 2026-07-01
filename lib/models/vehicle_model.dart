class VehicleModel {
  final String id;
  final String workshopId;
  final String plateNumber;
  final String? vin;
  final String? make;
  final String? model;
  final String? year;
  final String? color;
  final int? currentMileage;
  final String? thumbnailUrl;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.workshopId,
    required this.plateNumber,
    this.vin,
    this.make,
    this.model,
    this.year,
    this.color,
    this.currentMileage,
    this.thumbnailUrl,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      workshopId: json['workshop_id'],
      plateNumber: json['plate_number'],
      vin: json['vin'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      currentMileage: json['current_mileage'],
      thumbnailUrl: json['thumbnail_url'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      customerEmail: json['customer_email'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workshop_id': workshopId,
      'plate_number': plateNumber,
      'vin': vin,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'current_mileage': currentMileage,
      'thumbnail_url': thumbnailUrl,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
    };
  }
}
