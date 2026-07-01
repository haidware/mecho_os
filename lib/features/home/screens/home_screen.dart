import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/mecho_logo.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../repositories/workshop_repository.dart';
import '../../../repositories/dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../models/activity_model.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardRepository _repository = DashboardRepository();
  final WorkshopRepository _workshopRepo = WorkshopRepository();
  
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _activeVehicles = [];
  List<ActivityModel> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = supabase.Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await _workshopRepo.getWorkshopDetails(user.id);
        final stats = await _repository.getDashboardStats();
        final vehicles = await _repository.getActiveVehicles();
        final activities = await _repository.getRecentActivities();
        
        if (mounted) {
          setState(() {
            _profile = profile;
            _stats = stats;
            _activeVehicles = vehicles;
            _recentActivities = activities;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const MechoSearchBar(hintText: 'Search by Plate Number, VIN, or Customer...'),
                _buildStatGrid(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                _buildQuickActions(context),
                _buildSectionHeader(context, 'Active Vehicles', AppRoutes.activeVehicles),
                _buildActiveVehiclesList(),
                _buildSectionHeader(context, 'Recent Activity', AppRoutes.history),
                _buildRecentActivityList(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader() {
    final userProfile = _profile?['user'];
    final workshopProfile = _profile?['workshop'];
    
    final fullName = userProfile?['full_name'] ?? 'Ade';
    final firstName = fullName.split(' ')[0];
    final garageName = workshopProfile?['garage_name'] ?? 'Ade Motors Workshop';

    String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.menu, size: 28), onPressed: () {}),
              const SizedBox(width: 4),
              const MechoLogo(height: 35),
              const Spacer(),
              const Badge(label: Text('3'), child: Icon(Icons.notifications_none, size: 28)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                child: const CircleAvatar(
                  radius: 20, 
                  backgroundColor: Color(0xFF1D1DFF), 
                  child: Icon(Icons.person, color: Colors.white, size: 22)
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$greeting, $firstName 👋',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(garageName,
                              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withOpacity(0.2))
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.green),
                              SizedBox(width: 8),
                              Text('Open', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 11))
                            ]
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
        children: [
          _buildStatCard('Vehicles Today', _stats?['vehicles_today']?.toString() ?? '0', Icons.directions_car, Colors.orange, '↑ 0% vs yesterday'),
          _buildStatCard('Active Jobs', _stats?['active_jobs']?.toString() ?? '0', Icons.work_outline, Colors.blue, 'View all >'),
          _buildStatCard('Pending Approvals', _stats?['pending_approvals']?.toString() ?? '0', Icons.hourglass_empty, Colors.purple, 'View all >'),
          _buildStatCard('Revenue Today', currencyFormat.format(_stats?['revenue_today'] ?? 0), Icons.monetization_on_outlined, Colors.green, '↑ 0% vs yesterday'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String trend) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.1))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(trend, style: TextStyle(fontSize: 9, color: trend.contains('↑') ? Colors.green : Colors.black45, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'label': 'New Vehicle\nCheck-in', 'icon': Icons.add_circle_outline, 'route': AppRoutes.vehicleCheckin},
      {'label': 'New\nInspection', 'icon': Icons.assignment_outlined, 'route': AppRoutes.inspection},
      {'label': 'View\nApprovals', 'icon': Icons.check_circle_outline, 'route': AppRoutes.pendingApprovals},
      {'label': 'Record\nPayment', 'icon': Icons.payments_outlined, 'route': AppRoutes.payments},
      {'label': 'Contact\nBook', 'icon': Icons.contact_page_outlined, 'route': AppRoutes.customers},
      {'label': 'Maintenance\nCalendar', 'icon': Icons.calendar_month_outlined, 'route': AppRoutes.maintenance},
    ];
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal, itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => InkWell(
          onTap: () => Navigator.pushNamed(context, actions[index]['route'] as String, arguments: actions[index]['args']),
          child: Container(
            width: 100,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(actions[index]['icon'] as IconData, color: const Color(0xFF1D1DFF), size: 28), const SizedBox(height: 10), Text(actions[index]['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, height: 1.2))]),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveVehiclesList() {
    if (_activeVehicles.isEmpty && !_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('No active vehicles.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Column(children: _activeVehicles.map((data) {
      final vehicle = data['vehicles'];
      final status = data['status'] ?? 'Checked In';
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
        child: ListTile(
          leading: vehicle['thumbnail_url'] != null 
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(vehicle['thumbnail_url'], width: 55, height: 55, fit: BoxFit.cover))
            : const VehicleImageLoader(width: 55, height: 55, borderRadius: 8),
          title: Text(vehicle['plate_number'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          subtitle: Text('${vehicle['make']} ${vehicle['model']}\n${vehicle['customer_name']}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ]),
        ),
      );
    }).toList());
  }

  Widget _buildRecentActivityList() {
    if (_recentActivities.isEmpty && !_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('No recent activities.', style: TextStyle(color: Colors.grey))),
      );
    }

    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: _recentActivities.map((item) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const CircleAvatar(radius: 20, backgroundColor: Color(0xFFF8F9FC), child: Icon(Icons.history, size: 18, color: Colors.grey)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(DateFormat('hh:mm a').format(item.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black54))])),
        Text(DateFormat('MMM d').format(item.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    )).toList()));
  }

  Widget _buildSectionHeader(BuildContext context, String title, String route) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 32, 16, 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), GestureDetector(onTap: () => Navigator.pushNamed(context, route), child: const Text('View all', style: TextStyle(color: Color(0xFF1D1DFF), fontSize: 13, fontWeight: FontWeight.bold)))]));
  }
}
