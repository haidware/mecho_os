import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../models/inspection_model.dart';
import '../../../repositories/inspection_repository.dart';

class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final _repo = InspectionRepository();
  final _searchController = TextEditingController();
  
  Map<String, dynamic>? _activeCheckin;
  late List<InspectionItem> _items;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _resetItems();
  }

  void _resetItems() {
    _items = [
      InspectionItem(id: '1', title: 'Driveshaft / Brake Pads & Other Components', status: 'Good'),
      InspectionItem(id: '2', title: 'Coolant Leakage Test', status: 'Good'),
      InspectionItem(id: '3', title: 'Tyre Pressure Gauge', status: 'Good'),
      InspectionItem(id: '4', title: 'Under-Car Oil & Water Leakage Check', status: 'Good'),
      InspectionItem(id: '5', title: 'Filters Check', status: 'Good'),
      InspectionItem(id: '6', title: 'Battery Test & Auxiliary Battery', status: 'Good'),
      InspectionItem(id: '7', title: 'Diagnostics Oil Check', status: 'Good'),
      InspectionItem(id: '8', title: 'Diagnostic Lights Check', status: 'Good'),
      InspectionItem(id: '9', title: 'Coolant & Screen Wash Level', status: 'Good'),
      InspectionItem(id: '10', title: 'Full Diagnostics', status: 'Good'),
    ];
  }

  Future<void> _handleSearch(String value) async {
    if (value.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _repo.findActiveCheckin(value.trim());
      if (mounted) {
        if (result != null) {
          setState(() {
            _activeCheckin = result;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active check-in found for this vehicle.')));
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    if (_activeCheckin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please search for a vehicle first.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> itemsJson = _items
          .where((i) => i.isSelected)
          .map((i) => {
        'id': i.id,
        'title': i.title,
        'status': i.status,
        'notes': i.notes,
        'cost': i.estimatedRepairCost,
        'photos': i.photoUrls,
      }).toList();

      final vehicle = _activeCheckin!['vehicles'];
      final String activityDescription = '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']} - Inspected';

      await _repo.saveInspectionData(
        checkinId: _activeCheckin!['id'],
        workshopId: _activeCheckin!['workshop_id'],
        activityDescription: activityDescription,
        items: itemsJson,
        // Mileage usage is now saved at check-in
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspection saved and logged.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addPhotoToItem(InspectionItem item) async {
    final XFile? media = await _picker.pickImage(source: ImageSource.camera);
    if (media != null) {
      setState(() {
        item.photoUrls = List.from(item.photoUrls)..add(media.path);
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Critical': return Colors.red;
      case 'Attention': return Colors.orange;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    int goodCount = _items.where((i) => i.isSelected && i.status == 'Good').length;
    int attentionCount = _items.where((i) => i.isSelected && i.status == 'Attention').length;
    int criticalCount = _items.where((i) => i.isSelected && i.status == 'Critical').length;
    int selectedCount = _items.where((i) => i.isSelected).length;
    int totalCount = _items.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Vehicle Inspection', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildVehicleSummaryCard(),
                  MechoSearchBar(
                    hintText: "Search Plate or VIN...",
                    onSubmitted: _handleSearch,
                    controller: _searchController,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading) const Center(child: CircularProgressIndicator()),
                  ..._items.asMap().entries.map((entry) => _buildInspectionItem(entry.value, entry.key)),
                  _buildCounterSummary(goodCount, attentionCount, criticalCount, selectedCount, totalCount),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  Widget _buildInspectionItem(InspectionItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isSelected ? Colors.white : const Color(0xFFF8F9FC), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: item.isSelected ? const Color(0xFF1D1DFF).withOpacity(0.2) : Colors.grey.shade200)
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: item.isSelected, 
                activeColor: const Color(0xFF1D1DFF),
                onChanged: (v) => setState(() => item.isSelected = v ?? false)
              ),
              CircleAvatar(radius: 10, backgroundColor: const Color(0xFF1D1DFF), child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10))),
              const SizedBox(width: 8),
              Expanded(child: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: item.isSelected ? Colors.black : Colors.grey))),
              if (item.isSelected) _buildStatusBadge(item),
            ],
          ),
          if (item.isSelected) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 3, child: TextFormField(
                  initialValue: item.notes, 
                  onChanged: (v) => item.notes = v,
                  decoration: const InputDecoration(hintText: 'Add notes...', filled: true, fillColor: Color(0xFFF8F9FC), border: InputBorder.none, contentPadding: EdgeInsets.all(8)), 
                  style: const TextStyle(fontSize: 10), 
                  maxLines: 2
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addPhotoToItem(item),
                  child: Column(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: const Color(0xFF1D1DFF), size: 24),
                      Text('${item.photoUrls.length} Photos', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Est. Cost', style: TextStyle(fontSize: 8, color: Colors.grey)), 
                  TextFormField(
                    initialValue: item.estimatedRepairCost?.toString() ?? '0',
                    onChanged: (v) => item.estimatedRepairCost = double.tryParse(v) ?? 0,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '0'),
                  )
                ])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(InspectionItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: _getStatusColor(item.status).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: item.status, 
        icon: const Icon(Icons.keyboard_arrow_down, size: 14), 
        style: TextStyle(color: _getStatusColor(item.status), fontSize: 10, fontWeight: FontWeight.bold), 
        onChanged: (v) => setState(() => item.status = v!), 
        items: ['Good', 'Attention', 'Critical'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList()
      )),
    );
  }

  Widget _buildVehicleSummaryCard() {
    final vehicle = _activeCheckin?['vehicles'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Row(children: [
        VehicleImageLoader(imageUrl: vehicle?['thumbnail_url'], width: 100, height: 70), 
        const SizedBox(width: 16), 
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vehicle != null ? '${vehicle['make']} ${vehicle['model']}' : 'Search a Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
          Text(vehicle?['plate_number'] ?? 'ABC-000', style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.bold))
        ]))
      ])
    );
  }

  Widget _buildCounterSummary(int g, int a, int c, int selected, int total) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildCounter('Good', '$g', Colors.green), _buildCounter('Attention', '$a', Colors.orange), _buildCounter('Critical', '$c', Colors.red), _buildCounter('Total', '$selected/$total', const Color(0xFF1D1DFF))]);
  Widget _buildCounter(String l, String c, Color col) => Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(c, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col))]);
  
  Widget _buildActionButtons() => Row(children: [
    Expanded(child: OutlinedButton(onPressed: _handleSave, child: const Text('Save Progress'))), 
    const SizedBox(width: 12), 
    Expanded(child: ElevatedButton(onPressed: () async {
      if (_activeCheckin == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please search for a vehicle first.')));
        return;
      }

      await _handleSave();

      if (!mounted) return;

      Navigator.pushNamed(context, AppRoutes.quotationPreview, arguments: {
        'checkinId': _activeCheckin!['id'],
        'workshopId': _activeCheckin!['workshop_id'],
        'vehicle': _activeCheckin!['vehicles'],
        'customer': {
          'name': _activeCheckin!['vehicles']['customer_name'],
          'phone': _activeCheckin!['vehicles']['customer_phone'],
          'email': _activeCheckin!['vehicles']['customer_email'],
          'address': _activeCheckin!['vehicles']['customer_address'] ?? '...',
        },
        'inspectionItems': _items.where((i) => i.isSelected).map((i) => {
          'item': i.title,
          'status': i.status,
          'remarks': i.notes,
          'cost': i.estimatedRepairCost ?? 0,
          'photos': i.photoUrls,
        }).toList(),
        'quotationItems': _items.where((i) => i.isSelected && i.status != 'Good').map((i) => {
          'service': i.title,
          'desc': i.notes,
          'cost': i.estimatedRepairCost ?? 0,
        }).toList(),
      });
    }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF)), child: const Text('To Quotation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
  ]);
}
