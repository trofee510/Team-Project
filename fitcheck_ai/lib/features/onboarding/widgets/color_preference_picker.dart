import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class ColorPreferencePicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onChanged;

  const ColorPreferencePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _colorGroups = [
    ('neutrals', 'Neutrals', [Color(0xFF2D3436), Color(0xFF636E72), Color(0xFFDFE6E9), Color(0xFFFAFAFA)]),
    ('earth_tones', 'Earth Tones', [Color(0xFF8B6914), Color(0xFFA0522D), Color(0xFF6B8E23), Color(0xFFC4A882)]),
    ('pastels', 'Pastels', [Color(0xFFFFB5C5), Color(0xFFBFEFFF), Color(0xFFBDFCC9), Color(0xFFFFF0B5)]),
    ('bold', 'Bold', [Color(0xFFE74C3C), Color(0xFF3498DB), Color(0xFFF39C12), Color(0xFF9B59B6)]),
    ('monochrome', 'Monochrome', [Color(0xFF000000), Color(0xFF555555), Color(0xFFAAAAAA), Color(0xFFFFFFFF)]),
    ('jewel_tones', 'Jewel Tones', [Color(0xFF1B4F72), Color(0xFF7D3C98), Color(0xFF196F3D), Color(0xFF922B21)]),
    ('warm', 'Warm', [Color(0xFFFF6B6B), Color(0xFFFFA07A), Color(0xFFFFD93D), Color(0xFFFF8C42)]),
    ('cool', 'Cool', [Color(0xFF74B9FF), Color(0xFFA29BFE), Color(0xFF81ECEC), Color(0xFF55EFC4)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Colors you love',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick your go-to color palettes',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: _colorGroups.length,
              itemBuilder: (context, index) {
                final (id, label, colors) = _colorGroups[index];
                final isSelected = selected.contains(id);

                return GestureDetector(
                  onTap: () => onChanged(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Color swatches row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: colors
                              .map((c) => Container(
                                    width: 28,
                                    height: 28,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 0.5,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.check_circle,
                                  color: AppTheme.primary, size: 14),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
