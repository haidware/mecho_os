import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../services/auth_service.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _ownerController = TextEditingController();
  final _garageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  final _authService = AuthService();

  @override
  void dispose() {
    for (var c in [_ownerController, _garageController, _phoneController, _emailController, _passwordController, _addressController]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.registerGarageOwner(
        ownerName: _ownerController.text.trim(),
        garageName: _garageController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        garageAddress: _addressController.text.trim(),
        workshopType: 'General',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Account created successfully. Please login.'),
              backgroundColor: Colors.green
          ),
        );
        // Requirement: Navigate back to Login page with pre-filled credentials
        Navigator.pushReplacementNamed(
          context, 
          AppRoutes.login, 
          arguments: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        // CLEAN ERROR HANDLING
        String message = e.toString();
        if (message.contains('email-already-in-use')) {
          message = 'This email is already registered. Please login instead.';
        } else if (message.contains('invalid-email')) {
          message = 'The email address is not valid.';
        } else if (message.contains('weak-password')) {
          message = 'The password provided is too weak.';
        } else {
          // Remove the brackets [firebase_auth/...] for a cleaner look
          message = message.replaceAll(RegExp(r'\[.*\]'), '').trim();
          message = message.replaceAll('Exception:', '').trim();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildField(Icons.person_outline, 'Owner Name', _ownerController),
          const SizedBox(height: 16),
          _buildField(Icons.store_outlined, 'Garage Name', _garageController),
          const SizedBox(height: 16),
          _buildField(Icons.phone_outlined, 'Phone Number', _phoneController),
          const SizedBox(height: 16),
          _buildField(Icons.email_outlined, 'Email Address', _emailController),
          const SizedBox(height: 16),
          _buildField(
            Icons.lock_outline,
            'Password',
            _passwordController,
            isPassword: true,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 16),
          _buildField(Icons.location_on_outlined, 'Garage Address', _addressController),
          const SizedBox(height: 16),
          _buildField(Icons.handyman_outlined, 'Workshop Type', null, isDropdown: true),
          const SizedBox(height: 32),

          // PRIMARY SIGN UP BUTTON
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Stack(
                children: [
                  Center(
                      child: Text(
                          'Sign Up',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      )
                  ),
                  Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Icon(Icons.arrow_forward, size: 20)
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // BOTTOM NAVIGATION TEXT
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                  'Already have an account? ',
                  style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500)
              ),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                child: const Text(
                    'Login',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(IconData icon, String hint, TextEditingController? controller, {bool isPassword = false, bool isDropdown = false, Widget? suffix}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      readOnly: isDropdown,
      validator: (v) {
        if ((v == null || v.isEmpty) && !isDropdown) return 'Required';
        if (isPassword && v!.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.greyText),
        prefixIcon: Icon(icon, size: 20, color: Colors.black87),
        suffixIcon: isDropdown ? const Icon(Icons.keyboard_arrow_down_outlined) : suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}