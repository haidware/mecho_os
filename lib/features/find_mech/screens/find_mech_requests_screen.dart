import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FindMechRequestsScreen extends StatefulWidget {
  const FindMechRequestsScreen({super.key});

  @override
  State<FindMechRequestsScreen> createState() => _FindMechRequestsScreenState();
}

class _FindMechRequestsScreenState extends State<FindMechRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Find a Mech Requests',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'New Requests (2)'),
            Tab(text: 'Responded (0)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewRequestsList(),
          const Center(child: Text('No responded requests yet.')),
        ],
      ),
    );
  }

  Widget _buildNewRequestsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRequestCard(
          vehicle: 'Toyota Camry 2018',
          problem: 'Engine overheating',
          budget: '₦45,000 - ₦60,000',
          distance: '2.4 km away',
          time: '2h ago',
        ),
        const SizedBox(height: 16),
        _buildRequestCard(
          vehicle: 'Honda CR-V 2020',
          problem: 'Brake making noise',
          budget: '₦25,000 - ₦35,000',
          distance: '3.1 km away',
          time: '3h ago',
        ),
      ],
    );
  }

  Widget _buildRequestCard({
    required String vehicle,
    required String problem,
    required String budget,
    required String distance,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, color: Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(vehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                child: const Text('New', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Problem', problem),
          const SizedBox(height: 8),
          _buildInfoRow('Budget', budget),
          const SizedBox(height: 8),
          _buildInfoRow('Distance', distance),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('View Request', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Submit Estimate', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
