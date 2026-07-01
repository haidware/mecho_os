import 'package:flutter/material.dart';
import '../../../models/inspection_model.dart';

class QuotationScreen extends StatelessWidget {
  const QuotationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<InspectionItem> items = ModalRoute.of(context)!.settings.arguments as List<InspectionItem>? ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Create Quotation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Repair Items Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...items.map((item) => ListTile(
            leading: Icon(Icons.circle, size: 12, color: item.status == 'Critical' ? Colors.red : (item.status == 'Attention' ? Colors.orange : Colors.green)),
            title: Text(item.title),
            subtitle: Text(item.notes),
            trailing: Text('₦ ${item.estimatedRepairCost}', style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ],
      ),
    );
  }
}