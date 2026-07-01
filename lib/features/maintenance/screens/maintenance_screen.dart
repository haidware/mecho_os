import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/search_bar.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../repositories/maintenance_repository.dart';
import '../../../repositories/workshop_repository.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _maintenanceRepo = MaintenanceRepository();
  final _workshopRepo = WorkshopRepository();
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _filteredSchedules = [];
  String _activeTab = 'Upcoming';

  @override
  void initState() {
    super.initState();
    _loadMaintenanceData();
  }

  Future<void> _loadMaintenanceData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _workshopRepo.getWorkshopDetails(user.id);
      final workshopId = profile?['workshop']?['id'];

      if (workshopId != null) {
        final data = await _maintenanceRepo.getMaintenanceForCalendar(workshopId);
        if (mounted) {
          setState(() {
            _schedules = data;
            _filterSchedules();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading maintenance: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSchedules() {
    final now = DateTime.now();
    setState(() {
      if (_activeTab == 'Upcoming') {
        _filteredSchedules = _schedules.where((s) {
          final dueDate = DateTime.parse(s['due_date']);
          return dueDate.isAfter(now) && s['status'] == 'scheduled';
        }).toList();
      } else if (_activeTab == 'Overdue') {
        _filteredSchedules = _schedules.where((s) {
          final dueDate = DateTime.parse(s['due_date']);
          return dueDate.isBefore(now) && s['status'] == 'scheduled';
        }).toList();
      } else {
        _filteredSchedules = _schedules.where((s) => s['status'] == 'completed').toList();
      }
    });
  }

  void _onSearch(String value) {
    if (value.isEmpty) {
      _filterSchedules();
      return;
    }
    setState(() {
      _filteredSchedules = _filteredSchedules.where((s) {
        final vehicle = s['vehicles'];
        final plate = vehicle['plate_number']?.toString().toLowerCase() ?? '';
        final name = vehicle['customer_name']?.toString().toLowerCase() ?? '';
        final part = s['service_item']?.toString().toLowerCase() ?? '';
        return plate.contains(value.toLowerCase()) || 
               name.contains(value.toLowerCase()) || 
               part.contains(value.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Maintenance Calendar', 
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month, color: Color(0xFF1D1DFF)), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilterTabs(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: MechoSearchBar(
              hintText: 'Search part, plate or customer...',
              onSubmitted: _onSearch,
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMaintenanceData,
                  child: _filteredSchedules.isEmpty 
                    ? _buildEmptyState()
                    : _buildSchedulesList(),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final upcomingCount = _schedules.where((s) => DateTime.parse(s['due_date']).isAfter(DateTime.now())).length;
    final overdueCount = _schedules.where((s) => DateTime.parse(s['due_date']).isBefore(DateTime.now()) && s['status'] == 'scheduled').length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildSummaryCard('Due Soon', '$upcomingCount', Colors.blue),
          const SizedBox(width: 12),
          _buildSummaryCard('Overdue', '$overdueCount', Colors.red),
          const SizedBox(width: 12),
          _buildSummaryCard('Completed', '${_schedules.where((s) => s['status'] == 'completed').length}', Colors.green),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ['Upcoming', 'Overdue', 'History'].map((tab) {
          bool active = _activeTab == tab;
          return InkWell(
            onTap: () {
              setState(() => _activeTab = tab);
              _filterSchedules();
            },
            child: Column(
              children: [
                Text(tab, style: TextStyle(
                  fontSize: 13, 
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? const Color(0xFF1D1DFF) : Colors.black54
                )),
                const SizedBox(height: 8),
                if (active) Container(height: 3, width: 40, decoration: BoxDecoration(color: const Color(0xFF1D1DFF), borderRadius: BorderRadius.circular(2))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchedulesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _filteredSchedules[index];
        final vehicle = schedule['vehicles'];
        final dueDate = DateTime.parse(schedule['due_date']);
        final isOverdue = dueDate.isBefore(DateTime.now()) && schedule['status'] == 'scheduled';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  VehicleImageLoader(imageUrl: vehicle['thumbnail_url'], width: 60, height: 50, borderRadius: 8),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(schedule['service_item'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text('${vehicle['make']} ${vehicle['model']} • ${vehicle['plate_number']}', 
                            style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOverdue ? Colors.red : Colors.green).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      DateFormat('dd MMM').format(dueDate),
                      style: TextStyle(color: isOverdue ? Colors.red : Colors.green, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconText(Icons.person_outline, vehicle['customer_name']),
                  _buildIconText(Icons.speed_outlined, '${schedule['interval_km']} km interval'),
                  TextButton(
                    onPressed: () {
                      // Navigate to WhatsApp to remind customer
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                    child: const Text('Remind', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF1D1DFF))),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconText(IconData i, String t) {
    return Row(children: [Icon(i, size: 14, color: Colors.grey), const SizedBox(width: 6), Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87))]);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No $_activeTab maintenance records.', 
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
