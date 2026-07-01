import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/whatsapp_helper.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({super.key});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Future<String?> _captureReceipt() async {
    final uint8list = await _screenshotController.capture();
    if (uint8list != null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/service_receipt.png').create();
      await file.writeAsBytes(uint8list);
      return file.path;
    }
    return null;
  }

  Future<void> _handleDownload() async {
    final path = await _captureReceipt();
    if (path != null) {
      await Printing.sharePdf(bytes: await File(path).readAsBytes(), filename: 'Service_Receipt.png');
    }
  }

  Future<void> _handleShareReceipt(Map<String, dynamic> args) async {
    setState(() => _isSharing = true);
    try {
      // 1. Capture Visual Receipt
      final receiptPath = await _captureReceipt();

      // 2. Collect proof of work images
      final List<dynamic> serviceItems = args['serviceItems'] ?? [];
      List<String> proofImagePaths = [];
      for (var item in serviceItems) {
        if (item['proof_urls'] != null) {
          proofImagePaths.addAll(List<String>.from(item['proof_urls']));
        }
      }

      // 3. Share via Helper
      await WhatsAppHelper.sendInvoice(
        customerName: args['customerName'],
        garageName: 'Carbit Garage',
        phoneNumber: args['phoneNumber'] ?? '',
        proofImagePaths: proofImagePaths,
        amount: args['amountPaid'],
        invoiceFilePath: receiptPath,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sharing failed: $e')));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Service Receipt', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Receipt generated successfully.', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500))]),
              ),
              const SizedBox(height: 20),

              Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Receipt', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), Text(args['receiptId'], style: const TextStyle(color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold, fontSize: 16))]),
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, size: 40, color: Color(0xFF8E92BC))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _buildInfoColumn('Workshop', 'Carbit Garage', 'Workshop Address\nPhone Number')),
                        Expanded(child: _buildInfoColumn('Vehicle Info', args['vehicleModel'], 'Plate: ${args['plateNumber']}')),
                        Expanded(child: _buildInfoColumn('Customer Info', args['customerName'], 'Phone: ${args['phoneNumber']}')),
                      ]),
                      const SizedBox(height: 32),
                      _buildDetailRow('Receipt Number', args['receiptId']),
                      _buildDetailRow('Payment Method', 'Cash'),
                      _buildDetailRow('Payment Date', '${args['paymentDate']}'),
                      const SizedBox(height: 24),
                      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(12)), child: Column(children: [const Text('Amount Paid', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)), Text('₦${args['amountPaid']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green))])),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconAction(Icons.visibility_outlined, 'View', onTap: () {}),
                  _buildIconAction(Icons.download_outlined, 'Download', onTap: _handleDownload),
                  _buildIconAction(Icons.share_outlined, 'Share WhatsApp', 
                    isLoading: _isSharing,
                    onTap: () => _handleShareReceipt(args)
                  ),
                  _buildIconAction(Icons.history, 'History', onTap: () {}),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, color: Colors.white, size: 20), SizedBox(width: 10), Text('Close Job & Mark Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String header, String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(header, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), const SizedBox(height: 2), Text(sub, style: const TextStyle(fontSize: 9, color: Colors.black87, height: 1.3))]);
  Widget _buildDetailRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));
  Widget _buildIconAction(IconData i, String l, {required VoidCallback onTap, bool isLoading = false}) => Expanded(child: InkWell(onTap: isLoading ? null : onTap, child: Column(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(i, color: const Color(0xFF1D1DFF), size: 20)), const SizedBox(height: 4), SizedBox(width: 70, child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Color(0xFF1D1DFF), fontWeight: FontWeight.bold)))])));
}
