import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MaintenanceScheduleDialog extends StatefulWidget {
  final String partName;
  final String vehicleInfo;

  const MaintenanceScheduleDialog({
    super.key,
    required this.partName,
    required this.vehicleInfo,
  });

  @override
  State<MaintenanceScheduleDialog> createState() => _MaintenanceScheduleDialogState();
}

class _MaintenanceScheduleDialogState extends State<MaintenanceScheduleDialog> {
  final _partNameController = TextEditingController();
  final _intervalController = TextEditingController();
  DateTime? _calculatedDate;

  @override
  void initState() {
    super.initState();
    _partNameController.text = widget.partName;
    
    // Intelligent defaults based on part name
    if (widget.partName.toLowerCase().contains('oil')) {
      _intervalController.text = '5000';
    } else if (widget.partName.toLowerCase().contains('brake')) {
      _intervalController.text = '20000';
    } else if (widget.partName.toLowerCase().contains('belt')) {
      _intervalController.text = '80000';
    } else {
      _intervalController.text = '10000';
    }
    _calculateDate();
  }

  @override
  void dispose() {
    _partNameController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _calculateDate() {
    final interval = int.tryParse(_intervalController.text) ?? 0;
    if (interval <= 0) return;

    // Use a default average of 2000 km/month
    const double avgMonthlyKm = 2000.0; 
    final double monthsUntilDue = interval / avgMonthlyKm;
    final int daysUntilDue = (monthsUntilDue * 30).round();

    setState(() {
      _calculatedDate = DateTime.now().add(Duration(days: daysUntilDue));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Maintenance Scheduler', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Input the part replaced and its mileage interval to set an automatic reminder.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            
            const Text('Part / Service Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _partNameController,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Timing Belt, Spark Plugs...',
                filled: true,
                fillColor: const Color(0xFFF8F9FC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.settings_outlined, color: Color(0xFF1D1DFF), size: 20),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text('Mileage Interval (km)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateDate(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'e.g. 5000',
                filled: true,
                fillColor: const Color(0xFFF8F9FC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.speed, color: Color(0xFF1D1DFF), size: 20),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_calculatedDate != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1DFF).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1D1DFF).withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF1D1DFF), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Due Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            DateFormat('EEEE, dd MMM yyyy').format(_calculatedDate!),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1D1DFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'partName': _partNameController.text.trim(),
              'interval': int.tryParse(_intervalController.text) ?? 5000,
              'dueDate': _calculatedDate ?? DateTime.now().add(const Duration(days: 90)),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D1DFF), 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
          child: const Text('Set Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
