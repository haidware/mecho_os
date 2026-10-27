import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../repositories/workshop_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final WorkshopRepository _workshopRepo = WorkshopRepository();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await _workshopRepo.getWorkshopDetails(user.id);
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
          const CircleAvatar(radius: 14, backgroundColor: Color(0xFFF8F9FC), child: Icon(Icons.person_outline, size: 18, color: Colors.black)),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // User Header
              _buildUserHeader(),
              const SizedBox(height: 20),

              // OPERATIONS
              _buildSectionTitle('OPERATIONS'),
              _buildProfileItem(
                icon: Icons.people_outline,
                title: 'Customer Records',
                onTap: () => Navigator.pushNamed(context, AppRoutes.customers),
              ),
              _buildProfileItem(
                icon: Icons.bar_chart_outlined,
                title: 'Reports & Analytics',
                onTap: () => Navigator.pushNamed(context, AppRoutes.reportsDashboard),
              ),

              const SizedBox(height: 24),
              // FINANCE
              _buildSectionTitle('FINANCE'),
              _buildProfileItem(
                icon: Icons.account_balance_outlined,
                title: 'Bank Details',
                trailing: _buildUpdateBadge(),
                onTap: () => Navigator.pushNamed(context, AppRoutes.bankDetails),
              ),
              _buildProfileItem(
                icon: Icons.card_membership_outlined,
                title: 'Subscription Status',
                trailing: _buildStatusBadge('Active Trial'),
                onTap: () => Navigator.pushNamed(context, AppRoutes.subscription),
              ),

              const SizedBox(height: 24),
              // SUPPORT
              _buildSectionTitle('SUPPORT'),
              _buildProfileItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => Navigator.pushNamed(context, AppRoutes.chat), // Changed to help logic later
              ),
              _buildProfileItem(
                icon: Icons.forum_outlined,
                title: 'Community',
                onTap: () => Navigator.pushNamed(context, AppRoutes.community),
              ),

              const SizedBox(height: 24),
              // ACCOUNT
              _buildSectionTitle('ACCOUNT'),
              _buildProfileItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
              ),
              _buildProfileItem(
                icon: Icons.logout,
                title: 'Logout',
                titleColor: Colors.red,
                showTrailing: false,
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }

  Widget _buildUserHeader() {
    final fullName = _profile?['user']?['full_name'] ?? 'User Name';
    final initials = fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase();
    final garageName = _profile?['workshop']?['garage_name'] ?? 'Workshop Name';
    final email = _profile?['user']?['email'] ?? 'email@example.com';

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFFF8F9FC),
          child: Text(initials,
              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Owner • $garageName',
                  style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(email,
                  style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color? titleColor,
    bool showTrailing = true,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: titleColor ?? Colors.black87, size: 22),
      title: Text(title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor ?? Colors.black87)),
      trailing: trailing ?? (showTrailing ? const Icon(Icons.chevron_right, size: 20, color: Colors.grey) : null),
    );
  }

  Widget _buildUpdateBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Update', style: TextStyle(color: Color(0xFF1D1DFF), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ],
    );
  }

  Widget _buildStatusBadge(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ],
    );
  }
}
