import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/constants.dart';
import '../../core/extensions.dart';
import '../../core/theme.dart';
import '../../services/analytics_service.dart';
import '../../services/pro_status.dart';
import '../../services/subscription_service.dart';

/// Contextual paywall. Two pricing options with an annual anchor
/// (most users pick the highlighted yearly option — a ~60% lift vs weekly-only).
class PaywallScreen extends ConsumerStatefulWidget {
  /// Why the user saw the paywall — shapes the copy at the top.
  /// Values: 'limit', 'sub_scores', 'tips', 'history', 'watermark', 'default'
  final String? reason;

  const PaywallScreen({super.key, this.reason});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  static const _planAnnual = 'annual';
  static const _planWeekly = 'weekly';
  String _selected = _planAnnual;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).track(
          AnalyticsService.paywallViewed,
          props: {'reason': widget.reason ?? 'default'},
        );
  }

  String get _headline {
    switch (widget.reason) {
      case 'sub_scores':
        return 'Unlock your full breakdown';
      case 'tips':
        return 'Unlock personalized tips';
      case 'history':
        return 'See every score forever';
      case 'watermark':
        return 'Remove the watermark';
      case 'limit':
        return "You're on fire — keep going";
      default:
        return 'Unlock your full GRWM';
    }
  }

  String get _subhead {
    switch (widget.reason) {
      case 'sub_scores':
        return 'Color, style, occasion, versatility — see exactly what hit and what missed.';
      case 'tips':
        return 'Get 3 specific, actionable tips every time, tuned to your aesthetic.';
      case 'history':
        return 'Your scores disappear after 7 days on free. Keep every look, forever.';
      case 'limit':
        return "You've used today's free checks. Go Pro for unlimited.";
      default:
        return 'Unlimited checks, full breakdowns, personalized tips, and more.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // Close
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).canPop()
                      ? Navigator.pop(context)
                      : context.go('/home'),
                ),
              ),
              const SizedBox(height: 4),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                _headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _subhead,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              const _FeatureRow(
                icon: Icons.all_inclusive,
                text: 'Unlimited fit checks',
              ),
              const _FeatureRow(
                icon: Icons.insights,
                text: 'Full sub-score breakdown',
              ),
              const _FeatureRow(
                icon: Icons.tips_and_updates,
                text: 'Personalized style tips',
              ),
              const _FeatureRow(
                icon: Icons.history,
                text: 'Unlimited score history',
              ),
              const _FeatureRow(
                icon: Icons.cleaning_services,
                text: 'No watermark on share cards',
              ),
              const _FeatureRow(
                icon: Icons.group,
                text: 'Unlimited friend-mode battles',
              ),

              const SizedBox(height: 20),

              _PlanTile(
                planId: _planAnnual,
                selected: _selected == _planAnnual,
                title: 'Yearly',
                price: '\$59.99',
                priceSuffix: '/year',
                equivalent: 'Just \$1.15/week',
                badge: 'BEST VALUE · Save 83%',
                onTap: () => setState(() => _selected = _planAnnual),
              ),
              const SizedBox(height: 10),
              _PlanTile(
                planId: _planWeekly,
                selected: _selected == _planWeekly,
                title: 'Weekly',
                price: '\$6.99',
                priceSuffix: '/week',
                equivalent: '3-day free trial',
                onTap: () => setState(() => _selected = _planWeekly),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _startPurchase(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _selected == _planAnnual
                              ? 'Start yearly'
                              : 'Start 3-day trial',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final ok = await ref
                              .read(subscriptionServiceProvider)
                              .restorePurchases();
                          if (!context.mounted) return;
                          context.showSnackBar(
                              ok ? 'Pro restored' : 'Nothing to restore');
                          if (ok) ref.read(proStatusProvider.notifier).refresh();
                        } catch (e) {
                          if (context.mounted) {
                            context.showSnackBar('Restore failed: $e');
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Restore purchases'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cancel anytime. Billed by Apple/Google.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startPurchase(BuildContext context) async {
    final analytics = ref.read(analyticsServiceProvider);
    analytics.track(AnalyticsService.paywallPurchaseStarted,
        props: {'plan': _selected});
    setState(() => _busy = true);
    try {
      final svc = ref.read(subscriptionServiceProvider);
      final offerings = await svc.getOfferings();
      final current = offerings?.current;
      if (current == null) {
        if (context.mounted) {
          context.showSnackBar(
              'No active offering. Check RevenueCat dashboard.');
        }
        return;
      }

      final wantedId = _selected == _planAnnual
          ? AppConstants.productIdAnnual
          : AppConstants.productIdWeekly;

      // Prefer the package whose product matches, else fall back to
      // RC's semantic accessors (annual / weekly).
      final pkg = current.availablePackages.firstWhere(
        (p) => p.storeProduct.identifier == wantedId,
        orElse: () =>
            (_selected == _planAnnual ? current.annual : current.weekly) ??
            current.availablePackages.first,
      );

      final ok = await svc.purchasePackage(pkg);
      if (!context.mounted) return;
      if (ok) {
        analytics.track(AnalyticsService.paywallPurchaseSucceeded,
            props: {'plan': _selected});
        ref.read(proStatusProvider.notifier).refresh();
        context.showSnackBar('Welcome to Pro 🎉');
        Navigator.of(context).canPop()
            ? Navigator.pop(context)
            : context.go('/home');
      } else {
        context.showSnackBar(
            "Purchase didn't sync yet. Try 'Restore' in a moment.");
      }
    } on PlatformException catch (e) {
      analytics.track(AnalyticsService.paywallPurchaseFailed,
          props: {'code': e.code, 'message': e.message ?? ''});
      if (context.mounted) {
        if (e.code != '1') context.showSnackBar('Purchase failed: ${e.message}');
      }
    } catch (e, st) {
      analytics
        ..track(AnalyticsService.paywallPurchaseFailed,
            props: {'error': e.toString()})
        ..captureError(e, st, hint: 'paywall_purchase');
      if (context.mounted) context.showSnackBar('Purchase failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PlanTile extends StatelessWidget {
  final String planId;
  final bool selected;
  final String title;
  final String price;
  final String priceSuffix;
  final String equivalent;
  final String? badge;
  final VoidCallback onTap;

  const _PlanTile({
    required this.planId,
    required this.selected,
    required this.title,
    required this.price,
    required this.priceSuffix,
    required this.equivalent,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    equivalent,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  priceSuffix,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
