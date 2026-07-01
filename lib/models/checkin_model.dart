class CheckinModel {
  final String id;
  final String vehicleId;
  final String workshopId;
  final String status;
  final String? complaint;
  final int? mileageAtCheckin;
  final String? conditionAtArrival;
  final List<String>? photoUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  CheckinModel({
    required this.id,
    required this.vehicleId,
    required this.workshopId,
    required this.status,
    this.complaint,
    this.mileageAtCheckin,
    this.conditionAtArrival,
    this.photoUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CheckinModel.fromJson(Map<String, dynamic> json) {
    return CheckinModel(
      id: json['id'],
      vehicleId: json['vehicle_id'],
      workshopId: json['workshop_id'],
      status: json['status'],
      complaint: json['complaint'],
      mileageAtCheckin: json['mileage_at_checkin'],
      conditionAtArrival: json['condition_at_arrival'],
      photoUrls: json['photo_urls'] != null ? List<String>.from(json['photo_urls']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
