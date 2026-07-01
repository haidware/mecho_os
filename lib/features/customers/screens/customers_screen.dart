import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get workshop ID
      final userRes = await _supabase.from('users').select('workshop_id').eq('id', user.id).maybeSingle();
      final workshopId = userRes?['workshop_id'];

      if (workshopId != null) {
        final response = await _supabase
            .from('vehicles')
            .select()
            .eq('workshop_id', workshopId)
            .order('customer_name');
        
        if (mounted) {
          setState(() {
            _customers = List<Map<String, dynamic>>.from(response);
            _filteredCustomers = _customers;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String value) {
    setState(() {
      _filteredCustomers = _customers.where((c) {
        final name = c['customer_name']?.toString().toLowerCase() ?? '';
        final phone = c['customer_phone']?.toString().toLowerCase() ?? '';
        final plate = c['plate_number']?.toString().toLowerCase() ?? '';
        return name.contains(value.toLowerCase()) || 
               phone.contains(value.toLowerCase()) || 
               plate.contains(value.toLowerCase());
      }).toList();
    });
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
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
        title: const Text('Contact Book',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.addCustomer),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterTabs(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredCustomers.isEmpty 
                ? const Center(child: Text('No customers found.', style: TextStyle(color: Colors.grey)))
                : _buildCustomersList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Search by name, phone, or plate number',
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          filled: true,
          fillColor: const Color(0xFFF8F9FC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterTab('All Contacts (${_filteredCustomers.length})', true),
          _buildFilterTab('Frequent', false),
          _buildFilterTab('New', false),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? AppColors.primary : const Color(0xFFE5E7EB)),
      ),
      child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCustomersList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final c = _filteredCustomers[index];
        return _buildCustomerCard(
          context, 
          c['customer_name'] ?? 'Unknown', 
          '${c['make']} ${c['model']} (${c['plate_number']})', 
          'Phone: ${c['customer_phone']}', 
          _getInitials(c['customer_name'] ?? 'C')
        );
      },
    );
  }

  Widget _buildCustomerCard(BuildContext context, String name, String vehicle, String contact, String initials) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context, 
        AppRoutes.customerDetails, 
        arguments: {'customerName': name}
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF0F2FF),
              child: Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(vehicle, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w500)),
                  Text(contact, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
