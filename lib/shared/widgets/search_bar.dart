import 'package:flutter/material.dart';

class MechoSearchBar extends StatelessWidget {
  final String hintText;
  final EdgeInsets? padding;
  final Function(String)? onSubmitted;
  final TextEditingController? controller;

  const MechoSearchBar({
    super.key,
    this.hintText = 'Search Plate Number, VIN, or Customer Phone',
    this.padding,
    this.onSubmitted,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveController = controller ?? TextEditingController();
    
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: effectiveController,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () => onSubmitted?.call(effectiveController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D1DFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Search', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'e.g. ABC-123XY or 1HGCM82633A004352',
            style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
