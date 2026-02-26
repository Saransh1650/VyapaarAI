import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';

class StoreTypeScreen extends StatefulWidget {
  const StoreTypeScreen({super.key});
  @override
  State<StoreTypeScreen> createState() => _StoreTypeScreenState();
}

class _StoreTypeScreenState extends State<StoreTypeScreen> {
  String? _selected;

  static const _types = [
    {'type': 'grocery', 'label': 'Grocery', 'emoji': '🛒'},
    {'type': 'pharmacy', 'label': 'Pharmacy', 'emoji': '💊'},
    {'type': 'electronics', 'label': 'Electronics', 'emoji': '📱'},
    {'type': 'clothing', 'label': 'Clothing', 'emoji': '👗'},
    {'type': 'restaurant', 'label': 'Restaurant', 'emoji': '🍽'},
    {'type': 'general', 'label': 'General', 'emoji': '🏪'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 2')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What type of store do you run?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us tailor AI recommendations for your business.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: _types.map((t) {
                  final selected = _selected == t['type'];
                  return GestureDetector(
                    onTap: () => setState(() => _selected = t['type']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary.withOpacity(0.2)
                            : AppTheme.card,
                        border: Border.all(
                          color: selected
                              ? AppTheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t['emoji']!,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t['label']!,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
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
            ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () {
                      context.go(
                        AppConstants.routeOnboardingDetails,
                        extra: _selected,
                      );
                    },
              child: const Text('Next →'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Store Details Screen ──────────────────────────────────────────────────────

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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Step 2 of 2')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell us about your store',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(
                labelText: 'City / Region (optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Complete Setup'),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Onboarding Done ───────────────────────────────────────────────────────────

class OnboardingDoneScreen extends StatelessWidget {
  const OnboardingDoneScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 80),
            const SizedBox(height: 20),
            Text(
              'You\'re all set!',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Your store is ready. Let\'s start tracking.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.routeDashboard),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
}
