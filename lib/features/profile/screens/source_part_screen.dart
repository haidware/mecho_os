import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';

enum _ImageSelection { camera, gallery }

class SourcePartScreen extends StatefulWidget {
  const SourcePartScreen({super.key});

  @override
  State<SourcePartScreen> createState() => _SourcePartScreenState();
}

class _SourcePartScreenState extends State<SourcePartScreen> {
  static const _supportWhatsAppNumber = '2348127499576';
  static const _positions = [
    'Front Left',
    'Front Right',
    'Rear Left',
    'Rear Right',
    'Not applicable',
  ];

  final _formKey = GlobalKey<FormState>();
  final _partNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _garageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<XFile> _images = [];

  String? _selectedPosition;
  String? _selectedCondition;
  bool _isSending = false;

  @override
  void dispose() {
    _partNameController.dispose();
    _barcodeController.dispose();
    _vehicleController.dispose();
    _descriptionController.dispose();
    _garageController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectImages() async {
    try {
      final selection = await showModalBottomSheet<_ImageSelection>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, _ImageSelection.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, _ImageSelection.gallery),
              ),
            ],
          ),
        ),
      );
      if (!mounted || selection == null) return;

      final selected = selection == _ImageSelection.camera
          ? await _pickCameraImage()
          : await _imagePicker.pickMultiImage(
              limit: 5 - _images.length,
              imageQuality: 85,
            );
      if (!mounted || selected.isEmpty) return;

      setState(() {
        _images.addAll(selected.take(5 - _images.length));
      });
    } catch (error) {
      if (mounted) {
        _showMessage('Could not select images: $error', isError: true);
      }
    }
  }

  Future<List<XFile>> _pickCameraImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    return image == null ? [] : [image];
  }

  void _showBarcodeScanUnavailable() {
    _showMessage(
      'Live barcode scanning is not available yet. Enter the code manually or include a barcode photo.',
    );
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCondition == null) {
      _showMessage('Select whether you need a new or used part.',
          isError: true);
      return;
    }

    setState(() => _isSending = true);
    final message = [
      '*MECHO OS - SOURCE A PART REQUEST*',
      '',
      '*Part:* ${_partNameController.text.trim()}',
      '*Condition:* $_selectedCondition',
      '*Barcode / part number:* ${_optionalValue(_barcodeController.text)}',
      '*Vehicle:* ${_optionalValue(_vehicleController.text)}',
      '*Position:* ${_selectedPosition ?? 'Not specified'}',
      '*Description:* ${_optionalValue(_descriptionController.text)}',
      '*Name / garage:* ${_garageController.text.trim()}',
      '*Contact:* ${_phoneController.text.trim()}',
      '*Location:* ${_locationController.text.trim()}',
      '*Images attached:* ${_images.length}',
    ].join('\n');

    final uri = Uri.https('wa.me', '/$_supportWhatsAppNumber', {
      'text': message,
    });

    try {
      if (_images.isNotEmpty) {
        await Share.shareXFiles(
          _images,
          subject: 'Mecho OS - Source a Part Request',
          text: message,
        );
      } else {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          _showMessage(
            'WhatsApp could not be opened. Please try again or contact support.',
            isError: true,
          );
        }
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not share the request: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _optionalValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Source a Part',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child:
                        Icon(Icons.inventory_2_outlined, color: Colors.white),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Tell us what part you need. Add vehicle details and photos to help us find the right match.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(1, 'Identify the part'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _barcodeController,
              label: 'Barcode / part number',
              hint: 'Enter the code if available',
              prefixIcon: Icons.qr_code_2,
              suffixIcon: IconButton(
                tooltip: 'Scan barcode',
                onPressed: _showBarcodeScanUnavailable,
                icon: const Icon(Icons.qr_code_scanner_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _partNameController,
              label: 'Part name *',
              hint: 'e.g. Front shock absorber',
              prefixIcon: Icons.build_outlined,
              required: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _vehicleController,
              label: 'Vehicle make, model & year',
              hint: 'e.g. Toyota Corolla, 2015',
              prefixIcon: Icons.directions_car_outlined,
            ),
            const SizedBox(height: 24),
            _sectionTitle(2, 'Part condition'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: ['New', 'Used'].map((condition) {
                final selected = _selectedCondition == condition;
                return ChoiceChip(
                  label: Text(condition),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCondition = condition),
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.grey600,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionTitle(3, 'Where is the part located on the vehicle?'),
            const SizedBox(height: 6),
            const Text(
              'Choose a position if it applies.',
              style: TextStyle(color: AppColors.greyText, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _positions.map((position) {
                final selected = _selectedPosition == position;
                return ChoiceChip(
                  label: Text(position),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedPosition = position),
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary : AppColors.grey600,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionTitle(4, 'Describe what you need'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionController,
              label: 'Additional details',
              hint:
                  'Condition, engine size, OEM number, symptoms or other details that may help identify the correct part.',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            _sectionTitle(5, 'Add images'),
            const SizedBox(height: 12),
            InkWell(
              onTap: _images.length == 5 ? null : _selectImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 22,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _images.length == 5
                          ? 'Maximum of 5 images selected'
                          : 'Take a photo or choose images',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_images.length}/5 selected. Selected images will be included with your request.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.greyText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_images.length, (index) {
                  return _buildImagePreview(index, _images[index]);
                }),
              ),
            ],
            const SizedBox(height: 24),
            _sectionTitle(6, 'Your details and location'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _garageController,
              label: 'Your name / garage *',
              hint: 'Name or registered garage',
              prefixIcon: Icons.person_outline,
              required: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: 'Contact phone number *',
              hint: 'e.g. 08012345678',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              required: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _locationController,
              label: 'Your location / city *',
              hint: 'e.g. Akure, Ondo State',
              prefixIcon: Icons.location_on_outlined,
              required: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your request details and selected images will be included together in the share sheet. Choose WhatsApp to send them in one message.',
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendRequest,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  _isSending
                      ? 'Opening WhatsApp...'
                      : 'Send request via WhatsApp',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(int number, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.grey600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: required
              ? (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.greyText,
              fontSize: 13,
            ),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(int index, XFile file) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 76,
                  height: 76,
                  color: AppColors.secondary,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(
                snapshot.data!,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 76,
                  height: 76,
                  color: AppColors.secondary,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 3,
          right: 3,
          child: IconButton(
            onPressed: () => setState(() => _images.removeAt(index)),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    );
  }
}
