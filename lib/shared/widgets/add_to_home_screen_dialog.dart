import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AddToHomeScreenDialog extends StatelessWidget {
  const AddToHomeScreenDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isAppleDevice = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroidDevice = defaultTargetPlatform == TargetPlatform.android;

    return AlertDialog(
      title: const Text('Add Mecho OS to your Home Screen'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Install Mecho OS for quick access whenever you need it.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              if (!isAndroidDevice) ...[
                const _InstallInstructions(
                  title: 'iPhone and iPad',
                  browser:
                      'Open this link in Safari. Internet Explorer is not available on iPhone or iPad.',
                  steps: [
                    'Tap the Share button (the square with an arrow).',
                    'Choose “Add to Home Screen”, then tap “Add”.',
                  ],
                ),
                if (!isAppleDevice) const SizedBox(height: 16),
              ],
              if (!isAppleDevice)
                const _InstallInstructions(
                  title: 'Android',
                  browser: 'Open this link in Google Chrome.',
                  steps: [
                    'Tap the three-dot menu in the top corner.',
                    'Choose “Install app” or “Add to Home screen”.',
                    'Confirm by tapping “Install” or “Add”.',
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _InstallInstructions extends StatelessWidget {
  final String title;
  final String browser;
  final List<String> steps;

  const _InstallInstructions({
    required this.title,
    required this.browser,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(browser),
          const SizedBox(height: 8),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${index + 1}. ${steps[index]}'),
            ),
        ],
      ),
    );
  }
}
