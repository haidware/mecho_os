class ActivityModel {
  final String id;
  final String workshopId;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ActivityModel({
    required this.id,
    required this.workshopId,
    required this.description,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      workshopId: json['workshop_id'],
      description: json['description'],
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
