import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../repositories/seller_admin_api.dart';
import '../../../shared/widgets/mecho_logo.dart';

class SparePartSellerSignupScreen extends StatefulWidget {
  const SparePartSellerSignupScreen({super.key});

  @override
  State<SparePartSellerSignupScreen> createState() =>
      _SparePartSellerSignupScreenState();
}

class _SparePartSellerSignupScreenState
    extends State<SparePartSellerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = SellerAdminApi();
  final _sellerIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _sellerIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await _api.signupSeller(
        sellerId: _sellerIdController.text.trim(),
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.sparePartsSellerLogin,
        (_) => false,
        arguments: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
      appBar: AppBar(title: const Text('Seller Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: MechoLogo(height: 64)),
                      const SizedBox(height: 16),
                      const Text(
                        'Create a seller account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the one-time seller ID provided by the Mecho admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.greyText),
                      ),
                      const SizedBox(height: 24),
                      _field(
                        controller: _sellerIdController,
                        label: 'Seller ID number',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        validator: (value) => value == null ||
                                !RegExp(r'^\d{10}$').hasMatch(value.trim())
                            ? 'Enter the 10-digit ID provided by the admin.'
                            : null,
                      ),
                      _field(
                        controller: _nameController,
                        label: 'Name / business name',
                        icon: Icons.storefront_outlined,
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? 'Enter your name or business name.'
                                : null,
                      ),
                      _field(
                        controller: _emailController,
                        label: 'Email address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) => value == null ||
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())
                            ? 'Enter a valid email address.'
                            : null,
                      ),
                      _field(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value == null || value.trim().length < 7
                                ? 'Enter a valid phone number.'
                                : null,
                      ),
                      _field(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters.'
                            : null,
                      ),
                      _field(
                        controller: _confirmPasswordController,
                        label: 'Confirm password',
                        icon: Icons.lock_outline,
                        obscureText: _obscureConfirmation,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _signup,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Create seller account'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.sparePartsSellerLogin,
                        ),
                        child: const Text('Already registered? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SparePartsAdminScreen extends StatefulWidget {
  const SparePartsAdminScreen({super.key});

  @override
  State<SparePartsAdminScreen> createState() => _SparePartsAdminScreenState();
}

class _SparePartsAdminScreenState extends State<SparePartsAdminScreen> {
  final _api = SellerAdminApi();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _adminToken;
  String? _error;
  String? _sellerId;
  bool _isBusy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final token = await _api.loginAdmin(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) setState(() => _adminToken = token);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _generateId() async {
    final token = _adminToken;
    if (token == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
      _sellerId = null;
    });
    try {
      final ids = await _api.generateSellerIds(adminToken: token);
      if (mounted) setState(() => _sellerId = ids.single);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _copyId() async {
    final id = _sellerId;
    if (id == null) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller ID copied.')),
      );
    }
  }

  void _logout() {
    setState(() {
      _adminToken = null;
      _sellerId = null;
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _adminToken != null;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Seller ID Admin'),
        actions: [
          if (isLoggedIn)
            IconButton(
              tooltip: 'Sign out',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: isLoggedIn ? _generator() : _loginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Admin sign in',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _field(
            controller: _usernameController,
            label: 'Admin username',
            icon: Icons.person_outline,
            validator: (value) => value == null || value.isEmpty
                ? 'Enter the admin username.'
                : null,
          ),
          _field(
            controller: _passwordController,
            label: 'Admin password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Enter the admin password.'
                : null,
          ),
          if (_error != null) _errorMessage(),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isBusy ? null : _login,
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _generator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.confirmation_number_outlined,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        const Text(
          'Generate seller ID',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Each ID can be used once to create one spare-part seller account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.greyText),
        ),
        const SizedBox(height: 20),
        if (_error != null) _errorMessage(),
        if (_sellerId != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _sellerId!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy seller ID',
                  onPressed: _copyId,
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Copy and share this ID with the seller. It will not be shown again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.greyText, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isBusy ? null : _generateId,
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
            label: Text(_isBusy ? 'Generating...' : 'Generate new ID'),
          ),
        ),
      ],
    );
  }

  Widget _errorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: AppColors.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}

Widget _field({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  Widget? suffixIcon,
  bool obscureText = false,
  int? maxLength,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters:
          maxLength == 10 ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
      ),
    ),
  );
}
