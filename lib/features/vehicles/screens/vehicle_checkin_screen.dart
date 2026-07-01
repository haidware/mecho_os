import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/vehicle_image_loader.dart';
import '../../../repositories/vehicle_repository.dart';
import '../../../repositories/storage_repository.dart';

class VehicleCheckinScreen extends StatefulWidget {
  const VehicleCheckinScreen({super.key});

  @override
  State<VehicleCheckinScreen> createState() => _VehicleCheckinScreenState();
}

class _VehicleCheckinScreenState extends State<VehicleCheckinScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers initialized with Tobi's test data (can be cleared for production)
  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _plateController = TextEditingController();
  final _vinController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _mileageController = TextEditingController();
  final _complaintController = TextEditingController();

  String _selectedCondition = 'Running';
  bool _isSaving = false;

  String _selectedMileageUsage = 'Average (2,000 km/month)';
  final List<String> _mileageOptions = [
    'Low (1,000 km/month)',
    'Average (2,000 km/month)',
    'High (3,000 km/month)',
    'Commercial (5,000+ km/month)'
  ];

  final ImagePicker _picker = ImagePicker();
  final Map<String, File?> _pickedImages = {};

  final _vehicleRepo = VehicleRepository();
  final _storageRepo = StorageRepository();

  @override
  void dispose() {
    for (var c in [
      _customerNameController, _phoneController, _emailController,
      _plateController, _vinController, _makeController, _modelController,
      _yearController, _colorController, _mileageController, _complaintController
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia(String label) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) setState(() => _pickedImages[label] = File(photo.path));
  }

  // ROBUST WORKSHOP DISCOVERY LOGIC
  Future<String?> _getWorkshopId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    // 1. Check user profile for direct link
    final userResponse = await Supabase.instance.client.from('users').select('workshop_id').eq('id', user.id).maybeSingle();
    if (userResponse != null && userResponse['workshop_id'] != null) return userResponse['workshop_id'];

    // 2. Fallback: Search workshops table where Tobi is the owner
    final workshopResponse = await Supabase.instance.client.from('workshops').select('id').eq('owner_id', user.id).maybeSingle();

    if (workshopResponse != null) {
      // Repair the link in users table for future speed
      await Supabase.instance.client.from('users').update({'workshop_id': workshopResponse['id']}).eq('id', user.id);
      return workshopResponse['id'];
    }

    return null;
  }

  Future<void> _handleSave({bool navigateToInspect = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final workshopId = await _getWorkshopId();
      if (workshopId == null) throw 'Workshop not found for this account. Please ensure you registered as a mechanic.';

      // 1. Upload images to Supabase Storage
      List<String> uploadedUrls = [];
      String? thumbnailUrl;

      for (var entry in _pickedImages.entries) {
        if (entry.value != null) {
          final url = await _storageRepo.uploadVehiclePhoto(entry.value!, _plateController.text);
          if (url != null) {
            uploadedUrls.add(url);
            if (entry.key == 'Front') thumbnailUrl = url;
          }
        }
      }

      if (thumbnailUrl == null && uploadedUrls.isNotEmpty) thumbnailUrl = uploadedUrls.first;

      // 2. Prepare dynamic data
      final vehicleData = {
        'workshop_id': workshopId,
        'plate_number': _plateController.text.trim(),
        'vin': _vinController.text.trim(),
        'make': _makeController.text.trim(),
        'model': _modelController.text.trim(),
        'year': _yearController.text.trim(),
        'color': _colorController.text.trim(),
        'current_mileage': int.tryParse(_mileageController.text) ?? 0,
        'customer_name': _customerNameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'customer_email': _emailController.text.trim(),
        'thumbnail_url': thumbnailUrl,
      };

      final checkinData = {
        'workshop_id': workshopId,
        'status': navigateToInspect ? 'inspecting' : 'checked_in',
        'complaint': _complaintController.text.trim(),
        'mileage_at_checkin': int.tryParse(_mileageController.text) ?? 0,
        'condition_at_arrival': _selectedCondition,
        'estimated_monthly_usage': _selectedMileageUsage,
        'photo_urls': uploadedUrls,
      };

      // 3. Save to Supabase
      await _vehicleRepo.registerVehicleCheckin(
        vehicleData: vehicleData,
        checkinData: checkinData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(navigateToInspect ? 'Check-in completed. Starting inspection...' : 'Check-in draft saved.')),
        );
        if (navigateToInspect) {
          Navigator.pushNamed(context, AppRoutes.inspection);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0, backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1D1DFF), size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('New Vehicle Check-In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('1. Customer Information'),
                _buildInputRow([
                  _buildField('Customer Name *', 'e.g. John Doe', Icons.person_outline, _customerNameController),
                  _buildField('Phone Number *', 'e.g. 0801...', Icons.phone_outlined, _phoneController),
                ]),
                _buildField('Email (Optional)', 'e.g. email@gmail.com', Icons.email_outlined, _emailController),

                _buildSectionTitle('2. Vehicle Information'),
                _buildInputRow([
                  _buildField('Plate Number *', 'e.g. ABC-123', Icons.directions_car_filled_outlined, _plateController),
                  _buildField('VIN', 'Scan or type...', Icons.notes_outlined, _vinController, suffixAction: 'Scan VIN'),
                ]),
                _buildInputRow([
                  _buildField('Vehicle Make *', 'e.g. Toyota', Icons.directions_car_outlined, _makeController),
                  _buildField('Vehicle Model *', 'e.g. Camry', Icons.directions_car_outlined, _modelController),
                ]),
                _buildInputRow([
                  _buildField('Year *', 'e.g. 2018', Icons.calendar_today_outlined, _yearController),
                  _buildField('Color *', 'e.g. Silver', Icons.color_lens_outlined, _colorController),
                ]),
                _buildField('Current Mileage (km) *', 'e.g. 120,000', Icons.speed_outlined, _mileageController),

                const SizedBox(height: 16),
                _buildMileageUsageSection(),

                _buildSectionTitle('3. Vehicle Photos'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Front', 'Rear', 'Left', 'Right', 'Odometer'].map((l) => _buildPhotoPlaceholder(l)).toList(),
                  ),
                ),

                _buildSectionTitle('4. Customer Complaint'),
                _buildTextArea('Mechanic: input the customer complaint here...', _complaintController),

                _buildSectionTitle('5. Vehicle Condition'),
                _buildConditionSelection(),

                _buildSectionTitle('6. Check-In Summary'),
                _buildCheckinSummaryCard(),

                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }

  // --- Helper Widgets ---

  Widget _buildField(String l, String h, IconData i, TextEditingController controller, {String? suffixAction}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
            hintText: h, hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            prefixIcon: Icon(i, size: 18, color: const Color(0xFF1D1DFF)),
            suffixIcon: suffixAction != null ? TextButton(onPressed: () {}, child: Text(suffixAction, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D1DFF)))) : null,
            filled: true, fillColor: const Color(0xFFF8F9FC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14)
        ),
        validator: (v) => (v == null || v.isEmpty) && l.contains('*') ? 'Required' : null,
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildTextArea(String hint, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(fontSize: 12),
        filled: true, fillColor: const Color(0xFFF8F9FC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCheckinSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Row(children: [
        const VehicleImageLoader(width: 100, height: 80),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_customerNameController.text.isEmpty ? 'New Customer' : _customerNameController.text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          Text('${_makeController.text} ${_modelController.text} ${_yearController.text}', style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(_plateController.text.isEmpty ? 'Plate Number' : _plateController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1D1DFF))),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Next Service Forecast:\nDue in approx. 2.5 months', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)))
        ]))
      ]),
    );
  }

  Widget _buildPhotoPlaceholder(String label) {
    File? pickedFile = _pickedImages[label];
    return GestureDetector(
      onTap: () => _pickMedia(label),
      child: Container(
        width: 90, height: 90, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, style: BorderStyle.none), image: pickedFile != null ? DecorationImage(image: FileImage(pickedFile), fit: BoxFit.cover) : null),
        child: pickedFile == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt_outlined, color: Color(0xFF1D1DFF), size: 20), Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))]) : null,
      ),
    );
  }

  Widget _buildConditionSelection() {
    final conditions = ['Running', 'Non-Running', 'Accident', 'Towed In', 'Fleet'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: conditions.map((l) => GestureDetector(
          onTap: () => setState(() => _selectedCondition = l),
          child: Container(
            width: 100, height: 80, margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: _selectedCondition == l ? const Color(0xFF1D1DFF).withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _selectedCondition == l ? const Color(0xFF1D1DFF) : Colors.grey.shade200)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_car, color: _selectedCondition == l ? const Color(0xFF1D1DFF) : Colors.black54, size: 24), Text(l, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))]),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMileageUsageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1DFF).withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1D1DFF).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated Monthly Mileage Usage *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF)),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMileageUsage,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                          style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _selectedMileageUsage = newValue);
                            }
                          },
                          items: _mileageOptions.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  const Icon(Icons.bar_chart, size: 18, color: Color(0xFF1D1DFF)),
                                  const SizedBox(width: 8),
                                  Text(value),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This helps us predict service due-dates and send timely maintenance reminders.',
                      style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF1D1DFF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What this means',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on $_selectedMileageUsage, we\'ll estimate when your next services will be due and notify you in advance.',
                            style: const TextStyle(fontSize: 9, color: Colors.black54, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)));
  Widget _buildInputRow(List<Widget> children) => Row(children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList());

  Widget _buildActionButtons() {
    return Row(children: [
      Expanded(child: OutlinedButton(onPressed: _isSaving ? null : () => _handleSave(navigateToInspect: false), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.bold)))),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton(onPressed: _isSaving ? null : () => _handleSave(navigateToInspect: true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D1DFF), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Start Inspection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
    ]);
  }
}