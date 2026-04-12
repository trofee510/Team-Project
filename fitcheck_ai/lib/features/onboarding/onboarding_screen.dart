import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'widgets/aesthetic_picker.dart';
import 'widgets/body_type_picker.dart';
import 'widgets/color_preference_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Quiz answers
  final Set<String> _selectedAesthetics = {};
  String? _selectedBodyType;
  final Set<String> _selectedColors = {};

  static const _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    // TODO: Save to Supabase user_profiles when not in demo mode
    context.go('/home');
  }

  bool get _canProceed {
    return switch (_currentPage) {
      0 => _selectedAesthetics.isNotEmpty,
      1 => _selectedBodyType != null,
      2 => _selectedColors.isNotEmpty,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Row(
                      children: List.generate(_totalPages, (i) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i <= _currentPage
                                  ? AppTheme.primary
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text('Skip', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  AestheticPicker(
                    selected: _selectedAesthetics,
                    onChanged: (v) => setState(() {
                      if (_selectedAesthetics.contains(v)) {
                        _selectedAesthetics.remove(v);
                      } else {
                        _selectedAesthetics.add(v);
                      }
                    }),
                  ),
                  BodyTypePicker(
                    selected: _selectedBodyType,
                    onChanged: (v) => setState(() => _selectedBodyType = v),
                  ),
                  ColorPreferencePicker(
                    selected: _selectedColors,
                    onChanged: (v) => setState(() {
                      if (_selectedColors.contains(v)) {
                        _selectedColors.remove(v);
                      } else {
                        _selectedColors.add(v);
                      }
                    }),
                  ),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed ? _nextPage : null,
                  child: Text(
                    _currentPage == _totalPages - 1 ? 'Get Started' : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
