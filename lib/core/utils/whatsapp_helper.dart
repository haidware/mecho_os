import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class WhatsAppHelper {
  static Future<void> sendQuotation({
    required String customerName,
    required String garageName,
    required String phoneNumber,
    required List<String> imagePaths,
    String? quotationFilePath,
  }) async {
    final String message = '''
Hello $customerName,

Your vehicle inspection has been completed.

Attached:
• Inspection & Quotation Report
${imagePaths.isNotEmpty ? '• Inspection Photos' : ''}

Please review the report and let us know which repairs you approve.

For each approved repair, kindly indicate who will provide the parts:
• Garage
• Customer

Once we receive your approval, parts sourcing and service scheduling will begin.

Thank you.

$garageName
''';

    await _shareWithFiles(message, imagePaths, quotationFilePath);
  }

  static Future<void> sendInvoice({
    required String customerName,
    required String garageName,
    required String phoneNumber,
    required List<String> proofImagePaths,
    String? amount,
    String? invoiceFilePath,
  }) async {
    final String message = '''
Hello $customerName,

Your vehicle service has been completed successfully.

${amount != null ? 'Total Paid: ₦$amount' : ''}

Attached:
• Service Invoice
${proofImagePaths.isNotEmpty ? '• Proof of Work Photos' : ''}

Please find the details of the work done and the final charges.

Thank you for choosing $garageName.

Best regards.
''';

    await _shareWithFiles(message, proofImagePaths, invoiceFilePath);
  }

  static Future<void> _shareWithFiles(String message, List<String> images, String? primaryFile) async {
    List<XFile> filesToShare = [];

    // Add Primary File (Quotation/Invoice Image/PDF)
    if (primaryFile != null && await File(primaryFile).exists()) {
      filesToShare.add(XFile(primaryFile));
    }

    // Add Supporting Images
    for (var path in images) {
      if (path.isNotEmpty && await File(path).exists()) {
        filesToShare.add(XFile(path));
      }
    }

    if (filesToShare.isNotEmpty) {
      // Use Share sheet - Tobi selects WhatsApp
      await Share.shareXFiles(
        filesToShare,
        text: message,
      );
    } else {
      // Direct WhatsApp Text (No Files)
      // We try to use the phone number if provided
      final encodedMsg = Uri.encodeComponent(message);
      final url = Uri.parse("https://wa.me/?text=$encodedMsg");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(message);
      }
    }
  }
}
