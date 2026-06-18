// Flutter imports:
import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onVoiceSearch;
  final VoidCallback onCameraSearch;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onVoiceSearch,
    required this.onCameraSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(
              Icons.search,
              color: Color(0xFF636E72),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search items...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.mic,
              color: Color(0xFF4ECDC4),
              size: 22,
            ),
            onPressed: onVoiceSearch,
          ),
          IconButton(
            icon: const Icon(
              Icons.camera_alt,
              color: Color(0xFF4ECDC4),
              size: 22,
            ),
            onPressed: onCameraSearch,
          ),
        ],
      ),
    );
  }
}
