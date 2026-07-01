class InspectionItem {
  final String id;
  final String title;
  bool isSelected;
  String status; // 'Good', 'Attention', 'Critical'
  String notes;
  double estimatedRepairCost;
  List<String> photoUrls;

  InspectionItem({
    required this.id,
    required this.title,
    this.isSelected = true,
    this.status = 'Good',
    this.notes = '',
    this.estimatedRepairCost = 0.0,
    this.photoUrls = const [],
  });
}