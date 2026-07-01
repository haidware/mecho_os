import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../repositories/inspection_repository.dart';
import '../../../repositories/payment_repository.dart';

class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _searchRepo = InspectionRepository();
  final _paymentRepo = PaymentRepository();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  
  Map<String, dynamic>? _activeCheckin;
  bool _isLoading = false;
  String _selectedMethod = 'Cash';
  String _selectedType = 'Full Payment'; // 'Full Payment' or 'Deposit (Parts)'

  Future<void> _handleSearch(String value) async {
    if (value.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _searchRepo.findActiveCheckin(value.trim());
      if (mounted) {
        if (result != null) {
          setState(() {
            _activeCheckin = result;
            final List<dynamic> serviceItems = result['service_items'] ?? [];
            double total = 0;
            for (var item in serviceItems) {
              double labour = (item['labour_charge'] as num?)?.toDouble() ?? 0;
              double parts = (item['parts_cost'] as num?)?.toDouble() ?? 0;
              String sourcing = item['sourcing'] ?? 'Garage';

              total += labour;
              if (sourcing == 'Garage' || sourcing == 'Mecho Store') {
                total += parts;
              }
            }
            if (total > 0) {
              _amountController.text = total.toString();
            } else {
              _amountController.text = '0';
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active check-in found.')));
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitPayment() async {
    if (_activeCheckin == null) return;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final vehicle = _activeCheckin!['vehicles'];
      final String typeLabel = _selectedType == 'Full Payment' ? 'Full Payment' : 'Deposit';
      final String desc = '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']} - $typeLabel Received';
      
      await _paymentRepo.recordPayment(
        checkinId: _activeCheckin!['id'],
        workshopId: _activeCheckin!['workshop_id'],
        activityDescription: desc,
        amount: amount,
        markCompleted: _selectedType == 'Full Payment',
        paymentStatus: _selectedType == 'Full Payment' ? 'full' : 'deposit',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$typeLabel recorded successfully!')));
        Navigator.pushReplacementNamed(context, AppRoutes.receipts, arguments: {
          'receiptId': 'RCT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'invoiceId': 'INV-${_activeCheckin!['id'].toString().substring(0, 5).toUpperCase()}',
          'customerName': vehicle['customer_name'],
          'phoneNumber': vehicle['customer_phone'],
          'vehicleModel': '${vehicle['make']} ${vehicle['model']}',
          'plateNumber': vehicle['plate_number'],
          'amountPaid': NumberFormat('#,###').format(amount),
          'paymentDate': DateFormat('d MMM, yyyy').format(DateTime.now()),
          'serviceItems': _activeCheckin?['service_items'] ?? [],
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Record Payment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MechoSearchBar(
                hintText: 'Search Plate or VIN...',
                onSubmitted: _handleSearch,
                controller: _searchController,
              ),
              const SizedBox(height: 24),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              if (_activeCheckin != null) ...[
                _buildVehicleHeader(_activeCheckin!['vehicles']),
                const SizedBox(height: 32),
                const Text('Payment Type', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                _buildPaymentTypeSelector(),
                const SizedBox(height: 24),
                const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 16),
                _buildAmountField(),
                const SizedBox(height: 24),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 12),
                _buildPaymentMethods(),
                const SizedBox(height: 40),
                _buildSubmitButton(),
              ] else if (!_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Search for a vehicle to record payment', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleHeader(Map<String, dynamic> vehicle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          VehicleImageLoader(imageUrl: vehicle['thumbnail_url'], width: 80, height: 60, borderRadius: 8),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vehicle['make']} ${vehicle['model']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(vehicle['plate_number'], style: const TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.w900, fontSize: 13)),
                Text(vehicle['customer_name'], style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeSelector() {
    return Row(
      children: [
        _buildTypeOption('Deposit (Parts)'),
        const SizedBox(width: 12),
        _buildTypeOption('Full Payment'),
      ],
    );
  }

  Widget _buildTypeOption(String label) {
    bool isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1D1DFF).withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF1D1DFF) : Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                color: isSelected ? const Color(0xFF1D1DFF) : Colors.black87, 
                fontSize: 12, 
                fontWeight: FontWeight.w900
              )
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount to Pay (₦)', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8F9FC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      {'label': 'Cash', 'icon': Icons.money},
      {'label': 'Bank Transfer', 'icon': Icons.account_balance},
      {'label': 'POS / Card', 'icon': Icons.credit_card},
    ];

    return Row(
      children: methods.map((m) {
        bool isSelected = _selectedMethod == m['label'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMethod = m['label'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1D1DFF) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? const Color(0xFF1D1DFF) : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(m['icon'] as IconData, color: isSelected ? Colors.white : Colors.black54),
                  const SizedBox(height: 10),
                  Text(m['label'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _submitPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D1DFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text('Confirm & Generate Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }
}
