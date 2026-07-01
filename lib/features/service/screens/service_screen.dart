import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../core/constants/app_routes.dart';
import '../../../repositories/inspection_repository.dart';
import '../../../repositories/service_job_repository.dart';
import '../../../repositories/payment_repository.dart';
import '../../../repositories/storage_repository.dart';
import '../../../repositories/maintenance_repository.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../../../shared/dialogs/maintenance_schedule_dialog.dart';

class ServiceScreen extends StatefulWidget {
  final int initialTabIndex;
  const ServiceScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchRepo = InspectionRepository();
  final _serviceRepo = ServiceJobRepository();
  final _paymentRepo = PaymentRepository();
  final _storageRepo = StorageRepository();
  final _maintenanceRepo = MaintenanceRepository();
  final _searchController = TextEditingController();
  final _screenshotController = ScreenshotController();
  
  Map<String, dynamic>? _activeCheckin;
  bool _isLoading = false;
  int _currentLabourItemIndex = 0;

  // Controllers for current item
  final _labourChargeController = TextEditingController();
  final _workmanshipNoteController = TextEditingController();
  final Map<int, List<File>> _proofOfWorkImages = {};
  final Map<int, Map<String, dynamic>> _itemData = {}; // Stores per-item input

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('plateNumber')) {
        _searchController.text = args['plateNumber'];
        _handleSearch(args['plateNumber']);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _labourChargeController.dispose();
    _workmanshipNoteController.dispose();
    super.dispose();
  }

  void _saveCurrentItemData() {
    _itemData[_currentLabourItemIndex] = {
      'labourCharge': double.tryParse(_labourChargeController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0,
      'note': _workmanshipNoteController.text,
      'images': _proofOfWorkImages[_currentLabourItemIndex] ?? [],
    };
  }

  void _loadItemData(int index) {
    final data = _itemData[index] ?? {};
    _labourChargeController.text = data['labourCharge']?.toString() ?? '';
    _workmanshipNoteController.text = data['note'] ?? '';
  }

  Future<void> _handleSearch(String value) async {
    if (value.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _searchRepo.findActiveCheckin(value.trim());
      if (mounted) {
        if (result != null) {
          setState(() {
            _activeCheckin = result;
            _currentLabourItemIndex = 0;
            _itemData.clear();
            _proofOfWorkImages.clear();
            _loadItemData(0);
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

  Future<void> _pickProofImage() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _proofOfWorkImages[_currentLabourItemIndex] ??= [];
        _proofOfWorkImages[_currentLabourItemIndex]!.add(File(photo.path));
      });
    }
  }

  Future<void> _markCompleted() async {
    if (_activeCheckin == null) return;
    _saveCurrentItemData();

    setState(() => _isLoading = true);
    try {
      final vehicle = _activeCheckin!['vehicles'];
      final String desc = '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']} - Service Work Completed';
      
      final List<Map<String, dynamic>> finalItems = [];
      final List<dynamic> approvedItems = _activeCheckin?['approval_items'] ?? [];

      for (int i = 0; i < approvedItems.length; i++) {
        final itemInfo = approvedItems[i];
        final inputData = _itemData[i] ?? {};
        final List<File> files = _proofOfWorkImages[i] ?? [];
        List<String> urls = [];

        for (var file in files) {
          final url = await _storageRepo.uploadVehiclePhoto(file, '${vehicle['plate_number']}/proof_$i');
          if (url != null) urls.add(url);
        }

        finalItems.add({
          'title': itemInfo['title'],
          'labour_charge': inputData['labourCharge'] ?? 0,
          'note': inputData['note'] ?? '',
          'proof_urls': urls,
          'sourcing': itemInfo['sourcing'],
          'parts_cost': itemInfo['cost'] ?? 0,
        });
      }
      
      await _serviceRepo.saveServiceJobData(
        checkinId: _activeCheckin!['id'],
        workshopId: _activeCheckin!['workshop_id'],
        activityDescription: desc,
        status: 'ready_for_invoice',
        serviceItems: finalItems,
      );
      
      if (mounted) {
        setState(() {
          _activeCheckin!['service_items'] = finalItems;
          _activeCheckin!['status'] = 'ready_for_invoice';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service data saved. Moving to Invoice.')));
        _tabController.animateTo(2); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateTotalAmount(List<dynamic> items) {
    double total = 0;
    for (var item in items) {
      double labour = (item['labour_charge'] as num?)?.toDouble() ?? 0;
      double parts = (item['parts_cost'] as num?)?.toDouble() ?? 0;
      String sourcing = item['sourcing'] ?? 'Garage';

      total += labour;
      // Only add parts cost if sourced by the Garage or Mecho Store
      if (sourcing == 'Garage' || sourcing == 'Mecho Store') {
        total += parts;
      }
    }
    return total;
  }

  Future<void> _handlePayment() async {
    if (_activeCheckin == null) return;
    
    final List<dynamic> serviceItems = _activeCheckin?['service_items'] ?? [];
    double totalAmount = _calculateTotalAmount(serviceItems);
    
    setState(() => _isLoading = true);
    try {
      final vehicle = _activeCheckin!['vehicles'];
      final String desc = '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']} - Paid & Completed';
      
      await _paymentRepo.recordPayment(
        checkinId: _activeCheckin!['id'],
        workshopId: _activeCheckin!['workshop_id'],
        activityDescription: desc,
        amount: totalAmount, 
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully.')));
        Navigator.pushNamed(context, AppRoutes.receipts, arguments: {
          'receiptId': 'RCT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'invoiceId': 'INV-${_activeCheckin!['id'].toString().substring(0,5).toUpperCase()}',
          'customerName': vehicle['customer_name'],
          'phoneNumber': vehicle['customer_phone'],
          'vehicleModel': '${vehicle['make']} ${vehicle['model']}',
          'plateNumber': vehicle['plate_number'],
          'amountPaid': NumberFormat('#,###').format(totalAmount),
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

  Future<void> _startServiceWork() async {
    if (_activeCheckin == null) return;
    
    if (_activeCheckin!['status'] != 'In Service') {
      final vehicle = _activeCheckin!['vehicles'];
      await _serviceRepo.updateJobStatus(
        checkinId: _activeCheckin!['id'],
        workshopId: _activeCheckin!['workshop_id'],
        status: 'In Service',
        vehicleInfo: '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']}',
      );
      
      setState(() {
        _activeCheckin!['status'] = 'In Service';
      });
    }
    
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Service Work',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1D1DFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1D1DFF),
          indicatorWeight: 3,
          tabs: const [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.build_circle_outlined, size: 16), SizedBox(width: 4), Text('Approved')])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_outline, size: 16), SizedBox(width: 4), Text('Labour')])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.description_outlined, size: 16), SizedBox(width: 4), Text('Invoice')])),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildApprovedServicesTab(),
            _buildLabourChargesTab(),
            _buildInvoicePaymentTab(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _buildApprovedServicesTab() {
    final List<dynamic> approvedItems = _activeCheckin?['approval_items'] ?? [];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MechoSearchBar(
          hintText: 'Search Plate or VIN...',
          onSubmitted: _handleSearch,
          controller: _searchController,
        ),
        const SizedBox(height: 12),
        if (_isLoading) const Center(child: CircularProgressIndicator()),
        _buildVehicleHeader(_activeCheckin?['vehicles']),
        const SizedBox(height: 24),
        _buildStepper(activeStep: 3),
        const SizedBox(height: 24),
        _buildSummaryBox('Approved Items', approvedItems.length.toString(), 'Approved'),
        const SizedBox(height: 24),
        
        if (approvedItems.isEmpty && !_isLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('Search for a vehicle to see approved items.', style: TextStyle(color: Colors.grey)),
          )),

        ...approvedItems.asMap().entries.map((entry) => _buildApprovedJobCard(
          (entry.key + 1).toString(),
          entry.value['title'],
          'Approved',
          Colors.green,
          entry.value['note'] ?? 'No description',
          'Sourcing: ${entry.value['sourcing']}',
        )),
        
        const SizedBox(height: 20),
        if (approvedItems.isNotEmpty)
          _buildNavigationAction('Labour & Charges', _startServiceWork),
      ],
    );
  }

  Widget _buildLabourChargesTab() {
    final List<dynamic> approvedItems = _activeCheckin?['approval_items'] ?? [];
    final bool hasItems = approvedItems.isNotEmpty;
    final currentItem = hasItems ? approvedItems[_currentLabourItemIndex] : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVehicleHeader(_activeCheckin?['vehicles']),
        const SizedBox(height: 24),
        _buildStepper(activeStep: 3, step3Label: 'Service Work'),
        const SizedBox(height: 16),
        
        if (!hasItems)
          const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('Search for a vehicle in Approved tab first.', style: TextStyle(color: Colors.grey)),
          ))
        else ...[
          _buildServiceSelector(
            '${_currentLabourItemIndex + 1}. ${currentItem['title']}', 
            'In Progress',
            onNext: () {
              if (_currentLabourItemIndex < approvedItems.length - 1) {
                _saveCurrentItemData();
                setState(() => _currentLabourItemIndex++);
                _loadItemData(_currentLabourItemIndex);
              } else {
                _markCompleted();
              }
            },
            onPrev: () {
              if (_currentLabourItemIndex > 0) {
                _saveCurrentItemData();
                setState(() => _currentLabourItemIndex--);
                _loadItemData(_currentLabourItemIndex);
              }
            }
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _buildInputField('Labour Charge', '₦15,000', controller: _labourChargeController)),
            const SizedBox(width: 12),
            Expanded(child: _buildInputField('Workmanship Note', 'Notes...', maxLines: 4, charCount: '0 / 500', controller: _workmanshipNoteController)),
          ]),
          const SizedBox(height: 24),
          _buildPartsSection(currentItem['sourcing'] ?? 'Garage'),
          const SizedBox(height: 24),
          _buildProofOfWork(),
          const SizedBox(height: 32),
          _buildLabourActionButtons(),
          const SizedBox(height: 16),
          _buildNextServiceButton(
            isLast: _currentLabourItemIndex == approvedItems.length - 1,
            nextTitle: _currentLabourItemIndex < approvedItems.length - 1 
              ? approvedItems[_currentLabourItemIndex + 1]['title']
              : 'Invoice & Payment',
            onTap: () {
              if (_currentLabourItemIndex < approvedItems.length - 1) {
                _saveCurrentItemData();
                setState(() => _currentLabourItemIndex++);
                _loadItemData(_currentLabourItemIndex);
              } else {
                _markCompleted();
              }
            }
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInvoicePaymentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVehicleHeader(_activeCheckin?['vehicles']),
        const SizedBox(height: 24),
        _buildStepper(activeStep: 4),
        const SizedBox(height: 24),
        _buildInvoiceToggle(),
        const SizedBox(height: 24),
        _buildPaidInvoiceSection(),
        const SizedBox(height: 24),
        _buildInfoFooter('After payment is completed, click "Generate Receipt" to create an official receipt. Receipt generation is required before the service can be marked complete.'),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStepper({required int activeStep, String step3Label = 'Approved Services'}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _buildStep(1, 'Inspect', activeStep > 1), _buildStepDivider(activeStep > 1),
      _buildStep(2, 'Quotation', activeStep > 2), _buildStepDivider(activeStep > 2),
      _buildStep(3, step3Label, activeStep >= 3, isActive: activeStep == 3), _buildStepDivider(activeStep > 3),
      _buildStep(4, 'Invoice', activeStep >= 4), _buildStepDivider(activeStep > 4),
      _buildStep(5, 'Receipt', activeStep >= 5),
    ]);
  }

  Widget _buildStep(int n, String l, bool done, {bool isActive = false}) {
    Color color = done ? (isActive ? const Color(0xFF1D1DFF) : Colors.green) : Colors.grey.shade300;
    return Column(children: [
      CircleAvatar(radius: 12, backgroundColor: color, child: done && !isActive ? const Icon(Icons.check, size: 14, color: Colors.white) : Text('$n', style: const TextStyle(color: Colors.white, fontSize: 10))),
      const SizedBox(height: 4),
      Text(l, style: TextStyle(fontSize: 8, fontWeight: done ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _buildStepDivider(bool done) => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 22), color: done ? Colors.green : Colors.grey.shade300));

  Widget _buildVehicleHeader(Map<String, dynamic>? vehicle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Row(children: [
        VehicleImageLoader(imageUrl: vehicle?['thumbnail_url'], width: 100, height: 70),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vehicle != null ? '${vehicle['make']} ${vehicle['model']}' : 'Search a Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(vehicle != null ? '${vehicle['plate_number']} • ${vehicle['current_mileage']} km' : '...', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          Text(vehicle?['customer_name'] ?? '...', style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _buildApprovedJobCard(String n, String t, String status, Color col, String desc, String note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 10, backgroundColor: const Color(0xFF1D1DFF), child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 10))),
          const SizedBox(width: 8),
          Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(status, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        Row(children: [const VehicleImageLoader(width: 80, height: 50), const SizedBox(width: 12), Expanded(child: Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54)))]),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(fontSize: 10, color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold)),
        ]
      ]),
    );
  }

  Widget _buildServiceSelector(String val, String status, {required VoidCallback onNext, required VoidCallback onPrev}) {
    return Row(children: [
      Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)), child: Text(status, style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold))),
        const Spacer(),
        const Icon(Icons.keyboard_arrow_down),
      ]))),
      const SizedBox(width: 8),
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
    ]);
  }

  Widget _buildInputField(String l, String h, {int maxLines = 1, String? charCount, TextEditingController? controller}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      const SizedBox(height: 8),
      TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(hintText: h, filled: true, fillColor: const Color(0xFFF8F9FC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
      if (charCount != null) Align(alignment: Alignment.centerRight, child: Text(charCount, style: const TextStyle(fontSize: 9, color: Colors.grey))),
    ]);
  }

  Widget _buildPartsSection(String sourcing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF1D1DFF)),
          const SizedBox(width: 4),
          const Text('Parts Amount (NGN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)), child: Row(children: [Text('Part Source: $sourcing', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), const Icon(Icons.keyboard_arrow_down, size: 14)])),
        ]),
        const SizedBox(height: 12),
        _buildInputField('Estimated Parts Amount', '₦0.00'),
      ]),
    );
  }

  Widget _buildProofOfWork() {
    final images = _proofOfWorkImages[_currentLabourItemIndex] ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Proof of Work', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      const SizedBox(height: 12),
      Row(children: [
        ...images.map((file) => Container(
          width: 80, height: 80, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(file), fit: BoxFit.cover)),
        )),
        _buildAddMediaCard('Add Photos', Icons.add, onTap: _pickProofImage),
      ]),
    ]);
  }

  Widget _buildAddMediaCard(String label, IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80, height: 80, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF1D1DFF), size: 20), Text(label, style: const TextStyle(color: Color(0xFF1D1DFF), fontSize: 9, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildLabourActionButtons() {
    final List<dynamic> approvedItems = _activeCheckin?['approval_items'] ?? [];
    final currentItem = approvedItems.isNotEmpty ? approvedItems[_currentLabourItemIndex] : null;

    return Row(children: [
      Expanded(child: OutlinedButton(onPressed: () {
        _saveCurrentItemData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved locally.')));
      }, child: const Text('Save Draft', style: TextStyle(fontSize: 11)))),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton(onPressed: () async {
        if (currentItem == null) return;
        
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => MaintenanceScheduleDialog(
            partName: currentItem['title'],
            vehicleInfo: '${_activeCheckin!['vehicles']['make']} ${_activeCheckin!['vehicles']['model']}',
          ),
        );

        if (result != null) {
          await _maintenanceRepo.scheduleMaintenance(
            checkinId: _activeCheckin!['id'],
            vehicleId: _activeCheckin!['vehicle_id'],
            workshopId: _activeCheckin!['workshop_id'],
            partName: result['partName'],
            intervalMileage: result['interval'],
            dueDate: result['dueDate'],
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maintenance scheduled successfully!')));
          }
        }
      }, child: const Text('Add to Maintenance', style: TextStyle(fontSize: 11)))),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton(onPressed: _markCompleted, child: const Text('Mark Completed', style: TextStyle(fontSize: 11)))),
    ]);
  }

  Widget _buildNextServiceButton({required bool isLast, required String nextTitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1D1DFF), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(child: Text(isLast ? 'Finish: $nextTitle' : 'Next: $nextTitle', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Icon(isLast ? Icons.check_circle_outline : Icons.arrow_forward, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _buildInvoiceToggle() {
    return Row(children: [
      Expanded(child: Container(alignment: Alignment.center, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: const Text('Pending / Partial (1)', style: TextStyle(fontSize: 12, color: Colors.grey)))),
      const SizedBox(width: 8),
      Expanded(child: Container(alignment: Alignment.center, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1D1DFF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text('Paid (1)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D1DFF))))),
    ]);
  }

  Widget _buildPaidInvoiceSection() {
    final vehicle = _activeCheckin?['vehicles'];
    final List<dynamic> serviceItems = _activeCheckin?['service_items'] ?? [];
    final String invoiceId = _activeCheckin != null ? 'INV-${_activeCheckin!['id'].toString().substring(0, 5).toUpperCase()}' : 'INV-00000';
    
    double totalServiceAmount = _calculateTotalAmount(serviceItems);

    return Screenshot(
      controller: _screenshotController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)), child: const Text('Paid', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(invoiceId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VehicleImageLoader(imageUrl: vehicle?['thumbnail_url'], width: 80, height: 60),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vehicle != null ? '${vehicle['make']} ${vehicle['model']}' : 'Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(vehicle != null ? '${vehicle['plate_number']} • ${vehicle['current_mileage']} km' : '...', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                Text(vehicle?['customer_name'] ?? '...', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
            ],
          ),
        const Divider(height: 32),
        const Text('Service Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        ...serviceItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(item['title'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
              Text('₦${NumberFormat('#,###').format((item['labour_charge'] ?? 0) + ((item['sourcing'] == 'Garage' || item['sourcing'] == 'Mecho Store') ? (item['parts_cost'] ?? 0) : 0))}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        )),
        const Divider(height: 32),
        _buildPriceRow('Invoice Amount', '₦${NumberFormat('#,###').format(totalServiceAmount)}'),
          _buildPriceRow('Amount Paid', '₦${NumberFormat('#,###').format(totalServiceAmount)}', valueColor: Colors.green),
          _buildPriceRow('Payment Method', 'Cash'),
          _buildPriceRow('Payment Date', DateFormat('d MMM, yyyy').format(DateTime.now())),
          _buildPriceRow('Status', 'Paid', isStatus: true),
          const SizedBox(height: 24),
          _buildInvoiceActions(),
        ]),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? valueColor, bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          if (isStatus)
            Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 14), const SizedBox(width: 4), Text(value, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))])
          else
            Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black)),
        ],
      ),
    );
  }

  Widget _buildInvoiceActions() {
    final vehicle = _activeCheckin?['vehicles'];
    final List<dynamic> serviceItems = _activeCheckin?['service_items'] ?? [];
    
    double totalAmount = _calculateTotalAmount(serviceItems);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildOutlineAction(Icons.visibility_outlined, 'View Invoice', onTap: () {})),
            const SizedBox(width: 8),
            Expanded(child: _buildOutlineAction(Icons.download_outlined, 'Download PDF', onTap: () async {
              final uint8list = await _screenshotController.capture();
              if (uint8list != null) {
                await Printing.sharePdf(bytes: uint8list, filename: 'Invoice_Draft.png');
              }
            })),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildOutlineAction(Icons.share_outlined, 'WhatsApp', onTap: () async {
              if (vehicle == null) return;
              
              List<String> proofImagePaths = [];
              _proofOfWorkImages.forEach((index, files) {
                for (var file in files) {
                  proofImagePaths.add(file.path);
                }
              });

              final uint8list = await _screenshotController.capture();
              String? invoicePath;
              if (uint8list != null) {
                final tempDir = await getTemporaryDirectory();
                final file = await File('${tempDir.path}/invoice_draft.png').create();
                await file.writeAsBytes(uint8list);
                invoicePath = file.path;
              }

              await WhatsAppHelper.sendInvoice(
                customerName: vehicle['customer_name'] ?? 'Customer',
                garageName: 'Carbit Garage',
                phoneNumber: vehicle['customer_phone'] ?? '',
                proofImagePaths: proofImagePaths,
                amount: NumberFormat('#,###').format(totalAmount),
                invoiceFilePath: invoicePath,
              );
            })),
            const SizedBox(width: 8),
            Expanded(child: _buildOutlineAction(Icons.history, 'Payment Record', onTap: () {})),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _handlePayment,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Generate Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildOutlineAction(IconData icon, String label, {required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: Colors.grey.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSummaryBox(String l, String v, String s) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [Column(children: [const Text('Approved Items', style: TextStyle(fontSize: 10)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]), Text(s, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]));

  Widget _buildNavigationAction(String label, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF1D1DFF)), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Next: $label', style: const TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Icon(Icons.arrow_forward, color: Color(0xFF1D1DFF), size: 18)])));

  Widget _buildInfoFooter(String msg) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.info_outline, size: 16, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(msg, style: const TextStyle(fontSize: 10, color: Colors.black54)))]));
}
