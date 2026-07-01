import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../repositories/inspection_repository.dart';
import '../../../repositories/approval_repository.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  final _repo = InspectionRepository();
  final _approvalRepo = ApprovalRepository();
  final _searchController = TextEditingController();
  Map<String, dynamic>? _activeCheckin;
  bool _isLoading = false;

  List<Map<String, dynamic>> _items = [];

  Future<void> _handleSearch(String value) async {
    if (value.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _repo.findActiveCheckin(value.trim());
      if (mounted) {
        if (result != null) {
          setState(() {
            _activeCheckin = result;
            
            // Map inspection items from DB to approval items list
            final List<dynamic> dbItems = result['inspection_items'] ?? [];
            _items = dbItems.map((item) {
              return {
                'title': item['title'],
                'note': item['notes'] ?? '',
                'sourcing': 'Garage', 
                'approved': true, // Default to true if it came from inspection
                'cost': item['cost'] ?? 0,
              };
            }).toList();
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

  Future<void> _handleApprove() async {
    if (_activeCheckin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please search for a vehicle first.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final vehicle = _activeCheckin!['vehicles'];
      final String activityDescription = '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']} - Customer Approved';

      final List<Map<String, dynamic>> approvedOnly = _items.where((item) => item['approved'] == true).toList();

      await _approvalRepo.saveApprovalData(
        checkinId: _activeCheckin!['id'],
        workshopId: _activeCheckin!['workshop_id'],
        activityDescription: activityDescription,
        items: approvedOnly,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approval saved and logged.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int approvedCount = _items.where((i) => i['approved'] == true).length;
    final vehicle = _activeCheckin?['vehicles'];
    
    final double totalAmount = _items.where((i) => i['approved']).fold(0, (sum, item) => sum + (item['cost'] as num));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Customer Approval', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_none, color: Colors.black),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVehicleHeader(vehicle),
              const SizedBox(height: 12),

              MechoSearchBar(
                hintText: 'Search for repairs or it...',
                onSubmitted: _handleSearch,
                controller: _searchController,
              ),
              const SizedBox(height: 24),

              if (_isLoading) const Center(child: CircularProgressIndicator()),

              _buildStepper(),
              const SizedBox(height: 24),
              _buildQuotationSummaryCard(totalAmount),
              const SizedBox(height: 24),
              const Text('Items Awaiting Your Approval', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Please review and approve repairs.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 16),

              // APPROVAL ITEMS LIST
              if (_items.isEmpty && !_isLoading && _activeCheckin == null)
                _buildSearchPrompt()
              else if (_items.isEmpty && !_isLoading && _activeCheckin != null)
                _buildNoInspectionPrompt(),
              
              ..._items.asMap().entries.map((entry) => _buildApprovalItem(entry.value, entry.key)),

              _buildAddAdditionalServiceButton(),

              const SizedBox(height: 24),
              _buildInfoBanner(),
              const SizedBox(height: 24),
              const Text('Selected Items', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text('$approvedCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildActionButtons(approvedCount),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }

  Widget _buildVehicleHeader(Map<String, dynamic>? vehicle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade100), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
      ),
      child: Row(children: [
        VehicleImageLoader(imageUrl: vehicle?['thumbnail_url'], width: 100, height: 70),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vehicle != null ? '${vehicle['make']} ${vehicle['model']}' : 'Search a Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(vehicle?['plate_number'] ?? 'ABC-000', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(vehicle != null ? '${vehicle['customer_name']} • ${vehicle['current_mileage']} km' : '...', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]))
      ]),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStep(1, 'Check-In', true, false),
        _buildStepDivider(true),
        _buildStep(2, 'Inspect', true, false),
        _buildStepDivider(true),
        _buildStep(3, 'Quotation', true, false),
        _buildStepDivider(false),
        _buildStep(4, 'Approval', false, true),
        _buildStepDivider(false),
        _buildStep(5, 'Invoice', false, false),
        _buildStepDivider(false),
        _buildStep(6, 'History', false, false),
      ],
    );
  }

  Widget _buildStep(int n, String l, bool done, bool active) {
    Color bg = done ? Colors.green : (active ? const Color(0xFF1D1DFF) : Colors.grey.shade300);
    return Column(
      children: [
        CircleAvatar(radius: 12, backgroundColor: bg, child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : Text('$n', style: const TextStyle(color: Colors.white, fontSize: 10))),
        const SizedBox(height: 4),
        Text(l, style: TextStyle(fontSize: 8, fontWeight: (done || active) ? FontWeight.bold : FontWeight.normal, color: (done || active) ? Colors.black : Colors.grey)),
      ],
    );
  }

  Widget _buildStepDivider(bool active) => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 24), color: active ? Colors.green : Colors.grey.shade300));

  Widget _buildQuotationSummaryCard(double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)]
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: Color(0xFF1D1DFF), size: 20),
              const SizedBox(width: 10),
              const Text('Quotation Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              const Text('#QUO-250514-001', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)), 
              Text('₦ ${NumberFormat('#,###').format(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))
            ]
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              if (_activeCheckin != null) {
                Navigator.pushNamed(context, AppRoutes.quotationPreview, arguments: {
                  'vehicle': _activeCheckin!['vehicles'],
                  'inspectionItems': _activeCheckin!['inspection_items'] ?? [],
                  'quotationItems': _items.where((i) => i['approved']).toList(),
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.check_box_outlined, size: 18, color: Color(0xFF1D1DFF)), 
                  SizedBox(width: 12), 
                  Text('View Quotation Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), 
                  Spacer(), 
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey)
                ]
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item['approved'], 
                activeColor: const Color(0xFF1D1DFF), 
                onChanged: (v) => setState(() => item['approved'] = v!),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(item['note'], style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Parts Sourcing', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: item['sourcing'],
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black),
                        items: ['Garage', 'Mecho Store', 'Customer'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (newValue) => setState(() => item['sourcing'] = newValue!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('View Details', style: TextStyle(fontSize: 10, color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddAdditionalServiceButton() {
    return InkWell(
      onTap: () {},
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1D1DFF).withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: Color(0xFF1D1DFF), size: 22),
            SizedBox(width: 8),
            Text('Add Approved Service', style: TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(8)),
      child: const Row(children: [
        Icon(Icons.info_outline, size: 18, color: Color(0xFF1D1DFF)), 
        SizedBox(width: 12), 
        Expanded(child: Text('Prices include parts and labour. Additional costs may apply if new issues are found.', style: TextStyle(fontSize: 10, color: Color(0xFF1D1DFF), fontWeight: FontWeight.w600)))
      ]),
    );
  }

  Widget _buildActionButtons(int count) {
    return Column(children: [
      SizedBox(
        width: double.infinity, height: 56, 
        child: ElevatedButton(
          onPressed: _handleApprove, 
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), 
          child: Text('Approve Selected ($count)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
        )
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity, height: 56, 
        child: OutlinedButton(
          onPressed: () {
            final Map<String, dynamic>? args = _activeCheckin != null ? {'plateNumber': _activeCheckin!['vehicles']['plate_number']} : null;
            Navigator.pushReplacementNamed(context, AppRoutes.service, arguments: args);
          }, 
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE5E7EB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sync, size: 18, color: Colors.black54), SizedBox(width: 8), Text('Go To Services', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), Spacer(), Icon(Icons.arrow_forward, color: Colors.black54, size: 18)])
        )
      ),
    ]);
  }

  Widget _buildSearchPrompt() {
    return const Center(child: Padding(
      padding: EdgeInsets.all(40.0),
      child: Text('Search for a vehicle to see items.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
    ));
  }

  Widget _buildNoInspectionPrompt() {
    return const Center(child: Padding(
      padding: EdgeInsets.all(40.0),
      child: Column(
        children: [
          Icon(Icons.assignment_late_outlined, size: 48, color: Colors.orange),
          SizedBox(height: 16),
          Text('No inspection results found.', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Please complete the vehicle inspection first.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    ));
  }
}
