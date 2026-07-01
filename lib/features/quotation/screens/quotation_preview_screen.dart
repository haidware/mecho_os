import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../repositories/workshop_repository.dart';
import '../../../repositories/inspection_repository.dart';
import '../../../core/utils/whatsapp_helper.dart';

class QuotationPreviewScreen extends StatefulWidget {
  const QuotationPreviewScreen({super.key});

  @override
  State<QuotationPreviewScreen> createState() => _QuotationPreviewScreenState();
}

class _QuotationPreviewScreenState extends State<QuotationPreviewScreen> {
  final _workshopRepo = WorkshopRepository();
  final _inspectionRepo = InspectionRepository();
  final _screenshotController = ScreenshotController();
  
  Map<String, dynamic>? _workshopProfile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadWorkshopInfo();
  }

  Future<void> _loadWorkshopInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await _workshopRepo.getWorkshopDetails(user.id);
      if (mounted) {
        setState(() {
          _workshopProfile = profile;
        });
      }
    }
  }

  Future<String?> _captureReport() async {
    final uint8list = await _screenshotController.capture();
    if (uint8list != null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/quotation_report.png').create();
      await file.writeAsBytes(uint8list);
      return file.path;
    }
    return null;
  }

  Future<void> _handleDownload() async {
    final path = await _captureReport();
    if (path != null) {
      await Printing.sharePdf(bytes: await File(path).readAsBytes(), filename: 'Quotation_Report.png');
    }
  }

  Future<void> _handleSendToWhatsApp(String? checkinId, String? workshopId, Map<String, dynamic>? vehicle, List<dynamic>? inspectionItems) async {
    if (checkinId == null || workshopId == null || vehicle == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please search for a vehicle first.')));
       return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Save data to Supabase
      final activityDescription = '${vehicle['make']} ${vehicle['model']} • ${vehicle['customer_name']} - Quotation Shared';
      
      await _inspectionRepo.saveInspectionData(
        checkinId: checkinId,
        workshopId: workshopId,
        activityDescription: activityDescription,
        items: inspectionItems?.map((i) => {
          'title': i['item'],
          'status': i['status'],
          'notes': i['remarks'],
          'cost': i['cost'] ?? 0,
        }).toList() ?? [],
      );

      // 2. Capture Visual Report
      final reportPath = await _captureReport();

      // 3. Collect local inspection photos
      List<String> imagePaths = [];
      if (inspectionItems != null) {
        for (var item in inspectionItems) {
          if (item['photos'] != null) {
            imagePaths.addAll(List<String>.from(item['photos']));
          }
        }
      }

      // 4. Share via WhatsAppHelper
      await WhatsAppHelper.sendQuotation(
        customerName: vehicle['customer_name'] ?? 'Customer',
        garageName: _workshopProfile?['workshop']?['garage_name'] ?? 'Carbit Garage',
        phoneNumber: vehicle['customer_phone'] ?? '',
        imagePaths: imagePaths,
        quotationFilePath: reportPath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report and images prepared for sharing.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sharing failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    final vehicle = args?['vehicle'] ?? {
      'make': 'Toyota', 'model': 'Camry', 'year': '2018', 'plate_number': 'ABC-123XY',
      'vin': 'JTN81YHK1JJ3040152', 'current_mileage': 126300, 'color': 'Silver',
    };
    
    final customer = args?['customer'] ?? {
      'name': 'John Doe', 'phone': '+234 801 234 5678',
      'email': 'johndoe@email.com', 'address': '12 Allen Avenue, Ikeja, Lagos',
    };

    final workshop = {
      'name': _workshopProfile?['workshop']?['garage_name'] ?? 'CARBIT WORKSHOP',
      'address': _workshopProfile?['workshop']?['garage_address'] ?? 'Workshop Address',
      'phone': _workshopProfile?['workshop']?['phone_number'] ?? 'Workshop Phone',
      'email': _workshopProfile?['workshop']?['email'] ?? 'info@workshop.com',
      'website': 'www.workshop.com',
    };

    final List<dynamic> inspectionItems = args?['inspectionItems'] ?? [];
    final List<dynamic> quotationItems = args?['quotationItems'] ?? [];
    final double totalAmount = quotationItems.fold(0, (sum, item) => sum + (item['cost'] as num));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Quotation', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1D1DFF), width: 2))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility_outlined, color: Color(0xFF1D1DFF), size: 18), SizedBox(width: 8), Text('Preview', style: TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold))]),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewHeader(),
                    const SizedBox(height: 16),
                    
                    Screenshot(
                      controller: _screenshotController,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWorkshopInfo(workshop),
                            const Divider(height: 1),
                            _buildReportTitleInfo(vehicle['plate_number']),
                            const Divider(height: 1),
                            _buildContactIcons(workshop),
                            const Divider(height: 1),
                            _buildVehicleAndCustomerInfo(vehicle, customer),
                            const Divider(height: 1),
                            
                            if (inspectionItems.isNotEmpty) ...[
                              _buildSectionTitle('1', 'INSPECTION FINDINGS'),
                              _buildInspectionTable(inspectionItems),
                              _buildStatusLegend(),
                              const Divider(height: 1),
                            ],
                            
                            if (quotationItems.isNotEmpty) ...[
                              _buildSectionTitle(inspectionItems.isNotEmpty ? '2' : '1', 'QUOTATION'),
                              _buildQuotationTable(quotationItems),
                              _buildTotalFooter(totalAmount),
                            ],
                            
                            _buildValidityFooter(),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionIcon(Icons.fullscreen, 'Full Screen', onTap: () {}),
                        _buildActionIcon(Icons.download, 'Download', onTap: _handleDownload),
                        _buildActionIcon(Icons.bookmark_border, 'Save', onTap: () {}),
                        _buildActionIcon(Icons.share, 'Share', onTap: () => _handleSendToWhatsApp(args?['checkinId'], args?['workshopId'], vehicle, inspectionItems)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildWhatsAppButton(customer['phone'], args?['checkinId'], args?['workshopId'], vehicle, inspectionItems),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }

  Widget _buildPreviewHeader() {
    return Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF0F2FF), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.description_outlined, color: Color(0xFF1D1DFF))),
      const SizedBox(width: 16),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Quotation Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Preview the quotation before sending to customer', style: TextStyle(fontSize: 12, color: Colors.grey))]),
    ]);
  }

  Widget _buildWorkshopInfo(Map<String, dynamic> workshop) {
    return Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF001F3F), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 24)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(workshop['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF001F3F))), const Text('Quality Service. Trusted Care.', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))])),
    ]));
  }

  Widget _buildReportTitleInfo(String plate) {
    final now = DateTime.now();
    return Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('INSPECTION &', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF001F3F))),
        const Text('QUOTATION REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF001F3F))),
        const SizedBox(height: 8),
        Row(children: [const Icon(Icons.calendar_today, size: 10, color: Colors.grey), const SizedBox(width: 4), Text('Date: ${DateFormat('dd MMM, yyyy').format(now)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))]),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF001F3F), borderRadius: BorderRadius.circular(4)), child: Column(children: [const Text('QUOTATION NO.', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)), Text('QT-${plate.replaceAll('-','').toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])),
      ]),
    ]));
  }

  Widget _buildContactIcons(Map<String, dynamic> workshop) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _buildContactItem(Icons.location_on, workshop['address']),
      _buildContactItem(Icons.phone, workshop['phone']),
      _buildContactItem(Icons.email, workshop['email']),
      _buildContactItem(Icons.language, workshop['website']),
    ]));
  }

  Widget _buildContactItem(IconData icon, String text) => Row(children: [Icon(icon, size: 12, color: const Color(0xFF001F3F)), const SizedBox(width: 4), SizedBox(width: 60, child: Text(text, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis))]);

  Widget _buildVehicleAndCustomerInfo(Map<String, dynamic> vehicle, Map<String, dynamic> customer) {
    return Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.directions_car, size: 14), SizedBox(width: 8), Text('VEHICLE INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), _buildInfoField('Vehicle:', '${vehicle['make']} ${vehicle['model']}'), _buildInfoField('Plate Number:', vehicle['plate_number']), _buildInfoField('VIN:', vehicle['vin'] ?? 'N/A'), _buildInfoField('Mileage:', '${vehicle['current_mileage']} km')])),
      const SizedBox(width: 16),
      Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.person, size: 14), SizedBox(width: 8), Text('CUSTOMER INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), _buildInfoField('Name:', customer['name']), _buildInfoField('Phone:', customer['phone']), _buildInfoField('Address:', customer['address'])])),
      Expanded(flex: 1, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: VehicleImageLoader(imageUrl: vehicle['thumbnail_url'], width: double.infinity, height: 60))),
    ]));
  }

  Widget _buildInfoField(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(width: 4), Expanded(child: Text(value, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))]));

  Widget _buildSectionTitle(String sn, String title) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.grey.shade50, child: Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF001F3F), borderRadius: BorderRadius.circular(2)), child: Text(sn, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))]));

  Widget _buildInspectionTable(List<dynamic> items) {
    return Table(columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(3)}, children: [
      TableRow(decoration: const BoxDecoration(color: Color(0xFF001F3F)), children: [_buildTableHeader('ITEM'), _buildTableHeader('STATUS'), _buildTableHeader('REMARKS')]),
      ...items.map((i) => TableRow(children: [_buildTableCell(i['item']), _buildStatusCell(i['status']), _buildTableCell(i['remarks'] ?? 'No remarks')])),
    ]);
  }

  Widget _buildQuotationTable(List<dynamic> items) {
    return Table(columnWidths: const {0: FlexColumnWidth(0.5), 1: FlexColumnWidth(2), 2: FlexColumnWidth(3), 3: FlexColumnWidth(1.5)}, children: [
      TableRow(decoration: const BoxDecoration(color: Color(0xFF001F3F)), children: [_buildTableHeader('S/N'), _buildTableHeader('SERVICE / PARTS'), _buildTableHeader('DESCRIPTION'), _buildTableHeader('ESTIMATED COST (₦)')]),
      ...items.asMap().entries.map((entry) => TableRow(children: [_buildTableCell((entry.key + 1).toString()), _buildTableCell(entry.value['service']), _buildTableCell(entry.value['desc'] ?? ''), _buildTableCell(NumberFormat('#,###').format(entry.value['cost']), align: TextAlign.right)])),
    ]);
  }

  Widget _buildTableHeader(String text) => Padding(padding: const EdgeInsets.all(8), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)));
  Widget _buildTableCell(String text, {TextAlign align = TextAlign.left}) => Padding(padding: const EdgeInsets.all(8), child: Text(text, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500), textAlign: align));
  Widget _buildStatusCell(String status) => Padding(padding: const EdgeInsets.all(8), child: Row(children: [Icon(Icons.circle, size: 8, color: status == 'Critical' ? Colors.red : (status == 'Attention' ? Colors.orange : Colors.green)), const SizedBox(width: 4), Text(status, style: TextStyle(color: status == 'Critical' ? Colors.red : (status == 'Attention' ? Colors.orange : Colors.green), fontSize: 8, fontWeight: FontWeight.bold))]));

  Widget _buildStatusLegend() => const Padding(padding: EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_LegendItem(color: Colors.red, text: 'Critical'), _LegendItem(color: Colors.orange, text: 'Attention'), _LegendItem(color: Colors.green, text: 'Good')]));

  Widget _buildTotalFooter(double total) => Container(color: const Color(0xFF001F3F), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('ESTIMATED TOTAL', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)), Text('₦${NumberFormat('#,###').format(total)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))]));

  Widget _buildValidityFooter() => Container(width: double.infinity, padding: const EdgeInsets.all(12), color: const Color(0xFFF0F2FF), child: const Row(children: [Icon(Icons.info_outline, size: 14, color: Color(0xFF1D1DFF)), SizedBox(width: 8), Expanded(child: Text('This quotation is valid for 7 days. Prices may change after this date.', style: TextStyle(fontSize: 9, color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold)))]));

  Widget _buildActionIcon(IconData icon, String label, {required VoidCallback onTap}) => Expanded(child: InkWell(onTap: onTap, child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: const Color(0xFF1D1DFF), size: 24)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))])));

  Widget _buildWhatsAppButton(String phone, String? checkinId, String? workshopId, Map<String, dynamic>? vehicle, List<dynamic>? inspectionItems) {
    return SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: _isSaving ? null : () => _handleSendToWhatsApp(checkinId, workshopId, vehicle, inspectionItems),
      icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.chat, color: Colors.white),
      label: Text(_isSaving ? 'Processing...' : 'Send to Customer on WhatsApp', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
    ));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(Icons.circle, size: 6, color: color), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.black54))]);
  }
}
