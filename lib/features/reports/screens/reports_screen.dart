import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../repositories/reports_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportsRepository _repository = ReportsRepository();
  final ScreenshotController _screenshotController = ScreenshotController();
  
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getAnalyticsForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D1DFF),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _shareReport() async {
    try {
      final uint8list = await _screenshotController.capture();
      if (uint8list != null) {
        final tempDir = await getTemporaryDirectory();
        final String dateStr = DateFormat('dd_MMM_yyyy').format(_selectedDate);
        final file = await File('${tempDir.path}/MechoOS_Report_$dateStr.png').create();
        await file.writeAsBytes(uint8list);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Business Performance Report for ${DateFormat('dd MMM yyyy').format(_selectedDate)} - Mecho OS',
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sharing failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reports & Analytics',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.black, size: 20),
            onPressed: _selectDate,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1D1DFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1D1DFF),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Custom'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: const Color(0xFFFBFBFB),
                    child: Column(
                      children: [
                        _buildDateSelector(),
                        const SizedBox(height: 32),
                        _buildStatsGrid(currency),
                        const SizedBox(height: 32),
                        _buildRevenueTrendChart(currency),
                        const SizedBox(height: 32),
                        _buildAccountHistorySection(),
                        const SizedBox(height: 32),
                        _buildDownloadButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    final dateFormatted = DateFormat('EEEE, d MMM yyyy').format(_selectedDate);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black54),
          onPressed: () {
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
            _loadData();
          },
        ),
        InkWell(
          onTap: _selectDate,
          child: Text(dateFormatted, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.black54),
          onPressed: () {
            if (_selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 0)))) {
               setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
               _loadData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatsGrid(NumberFormat currency) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Revenue', currency.format(_analyticsData?['total_revenue'] ?? 0), '+ 12.5% vs yesterday', Colors.green)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Vehicles Serviced', '${_analyticsData?['vehicles_serviced'] ?? 0}', '+ 8.3% vs yesterday', Colors.blue)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('Deposits (Parts)', currency.format(_analyticsData?['total_deposits'] ?? 0), 'Advance payments', Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Full Payments', currency.format(_analyticsData?['total_full_payments'] ?? 0), 'Invoice completions', Colors.purple)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('Pending Approvals', '${_analyticsData?['pending_approvals'] ?? 0}', '- 4.0% vs yesterday', Colors.amber)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Avg Order Value', currency.format(_analyticsData?['avg_order_value'] ?? 0), '+ 15.2% vs yesterday', Colors.indigo)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String trend, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
          const SizedBox(height: 6),
          Text(trend, style: TextStyle(fontSize: 10, color: trend.startsWith('+') ? Colors.green : (trend.startsWith('-') ? Colors.red : Colors.grey), fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendChart(NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revenue Trend', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                child: Text(currency.format(_analyticsData?['total_revenue'] ?? 0), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: ChartPainter(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['8 AM', '10 AM', '12 PM', '2 PM', '4 PM', '6 PM'].map((t) => Text(t, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountHistorySection() {
    final List history = _analyticsData?['history'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 16),
        if (history.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('No transactions recorded for this date.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ))
        else
          ...history.map((item) => _buildHistoryItem(item)),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final metadata = item['metadata'] as Map<String, dynamic>?;
    final String? type = metadata?['type'];
    final String label = type == 'deposit' ? ' (DEPOSIT)' : (type == 'full' ? ' (FULL)' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, backgroundColor: Color(0xFFF8F9FC), child: Icon(Icons.history, size: 16, color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black),
                children: [
                  TextSpan(text: item['description']),
                  if (label.isNotEmpty)
                    TextSpan(
                      text: label, 
                      style: TextStyle(color: type == 'deposit' ? Colors.orange : Colors.green, fontSize: 10)
                    ),
                ],
              ),
            ),
            Text(DateFormat('hh:mm a').format(DateTime.parse(item['created_at'])), style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
          ])),
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _shareReport,
        icon: const Icon(Icons.share_outlined, color: Color(0xFF1D1DFF)),
        label: const Text('Share Performance Report', style: TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.w900, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D1DFF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.2, size.height * 0.6, size.width * 0.4, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.6, size.height * 0.9, size.width * 0.8, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.4);

    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = const Color(0xFF1D1DFF);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 6, dotPaint);
    
    final innerDotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 3, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
