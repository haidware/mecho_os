import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PayoutEarningsScreen extends StatelessWidget {
  const PayoutEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payout & Earnings',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 24),
            _buildEarningsOverview(),
            const SizedBox(height: 24),
            _buildRecentPayouts(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Available Balance', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text('₦78,450.00', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Pending Balance', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              const Text('₦15,230.00', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Earnings Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [Text('This Month', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), Icon(Icons.keyboard_arrow_down, size: 14)]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSimpleStat('Total Earnings', '₦245,600', '+ 16.4%', Colors.green),
              const VerticalDivider(),
              _buildSimpleStat('Completed Jobs', '86', '+ 12.2%', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, String trend, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(children: [Icon(Icons.arrow_upward, size: 10, color: color), Text(trend, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))]),
        ],
      ),
    );
  }

  Widget _buildRecentPayouts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Payouts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            TextButton(onPressed: () {}, child: const Text('See All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
          ],
        ),
        _buildPayoutItem('10 May, 2025', '₦45,000', 'Paid', Colors.green),
        _buildPayoutItem('28 Apr, 2025', '₦42,000', 'Paid', Colors.green),
        _buildPayoutItem('15 Apr, 2025', '₦35,000', 'Paid', Colors.green),
      ],
    );
  }

  Widget _buildPayoutItem(String date, String amount, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
