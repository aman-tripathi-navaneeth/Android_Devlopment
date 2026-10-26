import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// SearchField: debounced (300 ms), clear button, optional filter action (PART 4.7).
class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final int activeFilterCount;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onFilterTap,
    this.activeFilterCount = 0,
    this.controller,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChange(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(value);
    });
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outline, width: 1),
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onTextChange,
              style: AppTypography.body,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.inkSoft,
                  size: 20,
                ),
                hintText: widget.hintText,
                hintStyle: AppTypography.label.copyWith(
                  color: AppColors.inkSoft.withOpacity(0.7),
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.inkSoft,
                        ),
                        onPressed: _clear,
                        padding: EdgeInsets.zero,
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (widget.onFilterTap != null) ...[
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                onPressed: widget.onFilterTap,
                icon: const Icon(Icons.tune_rounded, color: AppColors.ink),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.outline, width: 1),
                  ),
                  minimumSize: const Size(44, 44),
                ),
              ),
              if (widget.activeFilterCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.matchaDeep,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.activeFilterCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
