import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

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

  static Future<void> _shareWithFiles(
      String message, List<String> images, String? primaryFile) async {
    final filesToShare = <XFile>[];
    final fileNameOverrides = <String>[];

    if (primaryFile != null && primaryFile.isNotEmpty) {
      await _addAttachment(primaryFile, filesToShare, fileNameOverrides);
    }

    for (var path in images) {
      if (path.isNotEmpty) {
        await _addAttachment(path, filesToShare, fileNameOverrides);
      }
    }

    if (filesToShare.isNotEmpty) {
      await Share.shareXFiles(
        filesToShare,
        text: message,
        subject: 'Mecho OS',
        fileNameOverrides: fileNameOverrides,
      );
    } else {
      final encodedMsg = Uri.encodeComponent(message);
      final url = Uri.parse("https://wa.me/?text=$encodedMsg");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(message);
      }
    }
  }

  static Future<void> _addAttachment(
    String path,
    List<XFile> files,
    List<String> fileNameOverrides,
  ) async {
    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Could not download an attachment (HTTP ${response.statusCode}).',
          uri: uri,
        );
      }

      final name = uri.pathSegments.isEmpty
          ? 'attachment'
          : Uri.decodeComponent(uri.pathSegments.last);
      final mimeType =
          response.headers['content-type']?.split(';').first.trim() ??
              _mimeTypeFor(name);
      files.add(XFile.fromData(
        response.bodyBytes,
        name: name,
        mimeType: mimeType,
      ));
      fileNameOverrides.add(name);
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Attachment file was not found', path);
    }

    files.add(XFile(path));
    fileNameOverrides.add(file.uri.pathSegments.last);
  }

  static String _mimeTypeFor(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}
