import 'package:flutter/material.dart';

class VehicleImageLoader extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  const VehicleImageLoader({
    super.key,
    this.imageUrl,
    this.width = 120,
    this.height = 80,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFF8F9FC),
        child: imageUrl != null && imageUrl!.startsWith('http')
            ? Image.network(
                imageUrl!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(Icons.directions_car_filled_outlined, color: Colors.grey.shade300, size: width * 0.4),
    );
  }
}
