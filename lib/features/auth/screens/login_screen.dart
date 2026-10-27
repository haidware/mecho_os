import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/auth_background.dart';
import '../widgets/login_form.dart';
import '../../../shared/widgets/mecho_logo.dart';

class LoginScreen extends StatelessWidget {
  final bool isSparePartSeller;

  const LoginScreen({super.key, this.isSparePartSeller = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthBackground(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const MechoLogo(height: 100),
                const SizedBox(height: 32),
                Text(
                    isSparePartSeller
                        ? 'Spare Part Seller Login'
                        : 'Login to Workshop',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(
                  isSparePartSeller
                      ? 'Sign in to view mechanic requests and respond with your price, part condition, and location. Seller accounts are provided by Mecho.'
                      : 'Manage your garage operations seamlessly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),
                LoginForm(
                  isSparePartSeller: isSparePartSeller,
                  initialEmail: (ModalRoute.of(context)?.settings.arguments
                      as Map?)?['email'],
                  initialPassword: (ModalRoute.of(context)?.settings.arguments
                      as Map?)?['password'],
                ),
                if (isSparePartSeller) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.login,
                    ),
                    child: const Text('Back to workshop login'),
                  ),
                ],
                const SizedBox(height: 32),
                if (!isSparePartSeller) ...[
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('NEW TO MECHO?',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Create Garage Account',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.storefront_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Login as Spare Part Seller',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Seller accounts are provided by Mecho. Respond to part requests with your price, condition, and location.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.sparePartsSellerLogin,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
