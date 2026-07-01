import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<Map<String, dynamic>> _languages = [
    {'name': 'English', 'code': 'en', 'flag': '🇺🇸'},
    {'name': 'Spanish', 'code': 'es', 'flag': '🇪🇸'},
    {'name': 'Greek (Cyprus)', 'code': 'el', 'flag': '🇨🇾'},
    {'name': 'Turkish (Cyprus)', 'code': 'tr', 'flag': '🇨🇾'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LANGUAGE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _languages.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = appLocale.value.languageCode == lang['code'];
                  
                  return ListTile(
                    onTap: () {
                      appLocale.value = Locale(lang['code']);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Language changed to ${lang['name']}'))
                      );
                    },
                    leading: Text(lang['flag'], style: const TextStyle(fontSize: 20)),
                    title: Text(lang['name'],
                        style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                    trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: Color(0xFF1D1DFF), size: 22)
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('NOTIFICATIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildToggleItem('Push Notifications', true),
            _buildToggleItem('WhatsApp Reminders', true),
            _buildToggleItem('Email Reports', false),
            
            const SizedBox(height: 24),
            const Text('APP INFO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildInfoItem('Version', '1.0.0 (Build 24)'),
            _buildInfoItem('Terms of Service', ''),
            _buildInfoItem('Privacy Policy', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String title, bool val) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Switch(
        value: val,
        onChanged: (v) {},
        activeColor: const Color(0xFF1D1DFF),
      ),
    );
  }

  Widget _buildInfoItem(String title, String trailing) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: trailing.isNotEmpty 
          ? Text(trailing, style: const TextStyle(fontSize: 12, color: Colors.grey))
          : const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }
}
