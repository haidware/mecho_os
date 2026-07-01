import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';

class NewApprovalsScreen extends StatefulWidget {
  const NewApprovalsScreen({super.key});

  @override
  State<NewApprovalsScreen> createState() => _NewApprovalsScreenState();
}

class _NewApprovalsScreenState extends State<NewApprovalsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allApprovals = [];
  String _selectedFilter = 'All Approvals';

  @override
  void initState() {
    super.initState();
    _fetchApprovals();
  }

  Future<void> _fetchApprovals() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final userRes = await _supabase.from('users').select('workshop_id').eq('id', user.id).maybeSingle();
      final workshopId = userRes?['workshop_id'];

      if (workshopId != null) {
        final response = await _supabase
            .from('checkins')
            .select('*, vehicles(*)')
            .eq('workshop_id', workshopId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _allApprovals = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching approvals: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('New Approvals', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          IconButton(icon: const Badge(label: Text('3'), child: Icon(Icons.notifications_none, color: Colors.black)), onPressed: () {}),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          _buildSearchBar(),
          _buildInfoBanner(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildApprovalsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildFilterTab('All Approvals', _allApprovals.length, _selectedFilter == 'All Approvals'),
            _buildFilterTab('Pending', 4, _selectedFilter == 'Pending', color: Colors.orange),
            _buildFilterTab('Partially', 1, _selectedFilter == 'Partially', color: Colors.blue),
            _buildFilterTab('Declined', 0, _selectedFilter == 'Declined', color: Colors.red),
            _buildFilterTab('Approved', 12, _selectedFilter == 'Approved', color: Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, int count, bool active, {Color? color}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? const Color(0xFF1D1DFF) : Colors.grey.shade100),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)] : null,
        ),
        child: Row(
          children: [
            if (color != null) CircleAvatar(radius: 4, backgroundColor: color),
            if (color != null) const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: active ? const Color(0xFF1D1DFF) : Colors.black54)),
                Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search customer, vehicle or VIN...',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          suffixIcon: const Icon(Icons.tune, color: Color(0xFF1D1DFF), size: 20),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF0F2FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1D1DFF).withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1D1DFF), size: 18),
          const SizedBox(width: 12),
          const Expanded(child: Text('Customer approval is required before work can begin.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF)))),
          TextButton(onPressed: () {}, child: const Text('Resend All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF)))),
        ],
      ),
    );
  }

  Widget _buildApprovalsList() {
    if (_allApprovals.isEmpty) {
      return const Center(child: Text('No approval requests found.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _allApprovals.length,
      itemBuilder: (context, index) => _buildApprovalCard(_allApprovals[index]),
    );
  }

  Widget _buildApprovalCard(Map<String, dynamic> data) {
    final vehicle = data['vehicles'];
    final List<dynamic> items = data['inspection_items'] ?? [];
    double total = 0;
    for (var item in items) total += (item['cost'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VehicleImageLoader(imageUrl: vehicle?['thumbnail_url'], width: 70, height: 55, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle?['plate_number'] ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    Text('${vehicle?['make']} ${vehicle?['model']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                    Text(vehicle?['customer_name'] ?? 'N/A', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₦${NumberFormat('#,###').format(total > 0 ? total : 85000)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF))),
                  const SizedBox(height: 4),
                  _buildStatusBadge(data['status'] ?? 'pending'),
                ],
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
          const Text('Requested Services', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: items.take(3).map((i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(6)),
              child: Text(i['title'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildActionBtn(Icons.visibility_outlined, 'View Details', isOutline: true)),
              const SizedBox(width: 10),
              Expanded(child: _buildActionBtn(Icons.send_outlined, 'Send Reminder')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color col = Colors.orange;
    String label = 'Pending';
    if (status == 'approved') { col = Colors.green; label = 'Approved'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: col.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: col.withOpacity(0.1))),
      child: Text(label.toUpperCase(), style: TextStyle(color: col, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildActionBtn(IconData i, String l, {bool isOutline = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isOutline ? Colors.white : const Color(0xFF1D1DFF),
        border: Border.all(color: isOutline ? Colors.grey.shade200 : const Color(0xFF1D1DFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i, size: 14, color: isOutline ? const Color(0xFF1D1DFF) : Colors.white),
          const SizedBox(width: 8),
          Text(l, style: TextStyle(color: isOutline ? const Color(0xFF1D1DFF) : Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
