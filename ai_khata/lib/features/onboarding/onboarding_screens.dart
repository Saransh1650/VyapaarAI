import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';

// ── Store Type Selection ───────────────────────────────────────────────────────

class StoreTypeScreen extends StatefulWidget {
  const StoreTypeScreen({super.key});
  @override
  State<StoreTypeScreen> createState() => _StoreTypeScreenState();
}

class _StoreTypeScreenState extends State<StoreTypeScreen> {
  String? _selected;

  static const _types = [
    {'type': 'grocery', 'label': 'Grocery / Kirana', 'emoji': '🛒'},
    {'type': 'pharmacy', 'label': 'Medical / Pharmacy', 'emoji': '💊'},
    {'type': 'electronics', 'label': 'Electronics', 'emoji': '📱'},
    {'type': 'clothing', 'label': 'Clothing / Fashion', 'emoji': '👗'},
    {'type': 'restaurant', 'label': 'Food & Restaurant', 'emoji': '🍽'},
    {'type': 'hardware', 'label': 'Hardware', 'emoji': '🔧'},
    {'type': 'stationery', 'label': 'Stationery', 'emoji': '📚'},
    {'type': 'general', 'label': 'Other Shop', 'emoji': '🏪'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'What kind of shop\ndo you run?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick the one that fits best.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: _types.map((t) {
                    final selected = _selected == t['type'];
                    return GestureDetector(
                      onTap: () => setState(() => _selected = t['type']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primarySurface
                              : AppTheme.card,
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              t['emoji']!,
                              style: const TextStyle(fontSize: 34),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t['label']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _selected == null
                    ? null
                    : () => context.go(
                        AppConstants.routeOnboardingDetails,
                        extra: _selected,
                      ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Store Details ──────────────────────────────────────────────────────────────

class StoreDetailsScreen extends StatefulWidget {
  final String storeType;
  const StoreDetailsScreen({super.key, required this.storeType});
  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthService>().completeOnboarding({
        'name': _nameCtrl.text.trim(),
        'region': _regionCtrl.text.trim(),
        'type': widget.storeType,
      });
      if (mounted) context.go(AppConstants.routeOnboardingDone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Name your shop',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This is how your shop will appear in the app.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 36),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  hintText: 'e.g. Sharma General Store',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your shop name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _regionCtrl,
                decoration: const InputDecoration(
                  labelText: 'City (optional)',
                  hintText: 'e.g. Mumbai',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textInputAction: TextInputAction.done,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Get Started 🚀'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Onboarding Done ────────────────────────────────────────────────────────────

class OnboardingDoneScreen extends StatelessWidget {
  const OnboardingDoneScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.success,
                size: 56,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your shop is ready!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Start adding bills and the app will track\nyour sales automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.routeDashboard),
              child: const Text('Open My Shop'),
            ),
          ],
        ),
      ),
    ),
  );
}
