import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';

class CustomerDetailsScreen extends StatefulWidget {
  const CustomerDetailsScreen({super.key});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, dynamic>? _customerData;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCustomerDetails();
    });
  }

  Future<void> _fetchCustomerDetails() async {
    setState(() => _isLoading = true);
    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String customerName = args?['customerName'] ?? 'Bayo';

      final customerRes = await _supabase
          .from('vehicles')
          .select()
          .ilike('customer_name', '%$customerName%')
          .limit(1)
          .maybeSingle();

      if (customerRes != null) {
        final actualName = customerRes['customer_name'];

        final vehiclesRes = await _supabase
            .from('vehicles')
            .select()
            .eq('customer_name', actualName);

        final List<String> vehicleIds = List<String>.from(vehiclesRes.map((v) => v['id'].toString()));
        final jobsRes = await _supabase
            .from('checkins')
            .select('*, vehicles(*)')
            .inFilter('vehicle_id', vehicleIds)
            .order('created_at', ascending: false);

        final List<String> checkinIds = List<String>.from(jobsRes.map((j) => j['id'].toString()));
        final paymentsRes = await _supabase
            .from('payments')
            .select()
            .inFilter('checkin_id', checkinIds)
            .order('created_at', ascending: false);

        final activityRes = await _supabase
            .from('activities')
            .select()
            .ilike('description', '%$actualName%')
            .order('created_at', ascending: false)
            .limit(10);

        if (mounted) {
          setState(() {
            _customerData = customerRes;
            _vehicles = List<Map<String, dynamic>>.from(vehiclesRes);
            _jobs = List<Map<String, dynamic>>.from(jobsRes);
            _payments = List<Map<String, dynamic>>.from(paymentsRes);
            _activities = List<Map<String, dynamic>>.from(activityRes);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching customer details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_customerData == null) return const Scaffold(body: Center(child: Text('Customer not found')));

    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final totalSpent = _payments.fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());
    
    double totalInvoiced = 0;
    for (var job in _jobs) {
      final List<dynamic> serviceItems = job['service_items'] ?? [];
      for (var item in serviceItems) {
        totalInvoiced += (item['labour_charge'] ?? 0) + (item['parts_cost'] ?? 0);
      }
    }
    if (totalInvoiced == 0) totalInvoiced = 287450; // Mock total if no jobs yet
    final outstanding = totalInvoiced - totalSpent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
            Text('Contacts > ${_customerData!['customer_name']}', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          const Badge(label: Text('3'), child: Icon(Icons.notifications_none, color: Colors.black)),
          const SizedBox(width: 8),
          const CircleAvatar(radius: 16, backgroundColor: Color(0xFF1D1DFF), child: Icon(Icons.person, color: Colors.white, size: 18)),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopStatsBar(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCustomerHeaderCard(currency, totalSpent, outstanding),
                  const SizedBox(height: 16),
                  _buildTabBar(),
                  const SizedBox(height: 16),
                  _buildOverviewContent(currency, totalInvoiced, totalSpent, outstanding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTopStatTab('All Customers (152)', true),
            _buildTopStatTab('Active Customers (134)', false, color: Colors.green),
            _buildTopStatTab('Non Active Customers (18)', false, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatTab(String label, bool active, {Color? color}) {
    return Container(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (color != null) CircleAvatar(radius: 3, backgroundColor: color),
              if (color != null) const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w900 : FontWeight.w600, color: active ? const Color(0xFF1D1DFF) : Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          if (active) Container(height: 3, width: 40, decoration: BoxDecoration(color: const Color(0xFF1D1DFF), borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildCustomerHeaderCard(NumberFormat currency, double totalSpent, double outstanding) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 35, backgroundColor: const Color(0xFFF8F9FC),
                    child: Text(_customerData!['customer_name']?.substring(0, 2).toUpperCase() ?? 'C', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF))),
                  ),
                  Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 12, backgroundColor: Colors.white, child: Icon(Icons.camera_alt_outlined, size: 14, color: Colors.grey.shade600))),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_customerData!['customer_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    _buildIconLabel(Icons.phone_outlined, _customerData!['customer_phone'] ?? 'N/A'),
                    _buildIconLabel(Icons.email_outlined, _customerData!['customer_email'] ?? 'N/A'),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildHeaderActionButton(Icons.edit_outlined, 'Edit'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                    child: const Text('New Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSmallHeaderStat('Vehicles', '${_vehicles.length}'),
              _buildSmallHeaderStat('Jobs', '${_jobs.length}'),
              _buildSmallHeaderStat('Spent', currency.format(totalSpent)),
              _buildSmallHeaderStat('Due', currency.format(outstanding), color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallHeaderStat(String l, String v, {Color? color}) {
    return Column(children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color ?? Colors.black))]);
  }

  Widget _buildIconLabel(IconData i, String l) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Row(children: [Icon(i, size: 12, color: Colors.black45), const SizedBox(width: 6), Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54))]));

  Widget _buildHeaderActionButton(IconData i, String l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [Icon(i, size: 12, color: const Color(0xFF1D1DFF)), const SizedBox(width: 6), Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF)))]),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: const Color(0xFF1D1DFF), unselectedLabelColor: Colors.black54,
      indicatorColor: const Color(0xFF1D1DFF), indicatorWeight: 3,
      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      tabs: const [Tab(text: 'Overview'), Tab(text: 'Vehicles'), Tab(text: 'Maintenance'), Tab(text: 'Payments'), Tab(text: 'Documents'), Tab(text: 'History')],
    );
  }

  Widget _buildOverviewContent(NumberFormat currency, double totalInvoiced, double totalSpent, double outstanding) {
    return Column(
      children: [
        _buildSectionHeader('Vehicles', 'View all vehicles'),
        const SizedBox(height: 12),
        ..._vehicles.map((v) => _buildMobileVehicleCard(v)),
        const SizedBox(height: 24),
        _buildSectionHeader('Recent Jobs', 'View all jobs'),
        _buildMobileJobsList(currency),
        const SizedBox(height: 24),
        _buildSidebarCard('Payment Overview', [
          _buildSidebarRow('Total Invoiced', currency.format(totalInvoiced)),
          _buildSidebarRow('Total Paid', currency.format(totalSpent), valueColor: Colors.green),
          _buildSidebarRow('Outstanding', currency.format(outstanding), valueColor: Colors.red),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String action) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF)))]);
  }

  Widget _buildMobileVehicleCard(Map<String, dynamic> v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          VehicleImageLoader(imageUrl: v['thumbnail_url'], width: 60, height: 45, borderRadius: 8),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${v['make']} ${v['model']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), Text(v['plate_number'], style: const TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.w900, fontSize: 11))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Text('Active', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _buildMobileJobsList(NumberFormat currency) {
    return Column(
      children: _jobs.take(3).map((job) {
        final List<dynamic> serviceItems = job['service_items'] ?? [];
        double total = 0;
        for (var item in serviceItems) total += (item['labour_charge'] ?? 0) + (item['parts_cost'] ?? 0);
        if (total == 0) total = 78450;
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('JOB-${job['id'].toString().substring(0, 5).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)), Text(DateFormat('dd MMM, yyyy').format(DateTime.parse(job['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900))]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₦${currency.format(total)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), _buildStatusBadge(job['status'] ?? 'Completed')]),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color col = status.toLowerCase() == 'completed' ? Colors.green : const Color(0xFF1D1DFF);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(status, style: TextStyle(color: col, fontSize: 8, fontWeight: FontWeight.w900)));
  }

  Widget _buildSidebarCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 16), ...children]),
    );
  }

  Widget _buildSidebarRow(String l, String v, {Color? valueColor}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w900)), Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: valueColor ?? Colors.black87))]));
  }
}
