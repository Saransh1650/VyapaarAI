import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../auth/auth_service.dart';
import 'package:provider/provider.dart';

// ── Bills List Screen ─────────────────────────────────────────────────────────

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});
  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<dynamic> _bills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.dio.get('/bills');
      setState(() {
        _bills = res.data['bills'] ?? [];
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppTheme.primary,
              ),
              title: const Text('Scan Bill (OCR)'),
              onTap: () {
                Navigator.pop(context);
                context.go(AppConstants.routeBillScanner);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppTheme.primaryLight,
              ),
              title: const Text('Enter Manually'),
              onTap: () {
                Navigator.pop(context);
                context.go(AppConstants.routeBillManual);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _bills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          color: AppTheme.textSecondary,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No bills yet',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bills.length,
                    itemBuilder: (_, i) {
                      final b = _bills[i];
                      return _BillCard(b, onTap: () => _load());
                    },
                  ),
          ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showAddOptions,
      icon: const Icon(Icons.add),
      label: const Text('Add Bill'),
      backgroundColor: AppTheme.primary,
    ),
  );
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final VoidCallback? onTap;
  const _BillCard(this.bill, {this.onTap});

  Color _statusColor(String? s) => switch (s) {
    'COMPLETED' => AppTheme.success,
    'FAILED' => AppTheme.error,
    'PROCESSING' => AppTheme.warning,
    _ => AppTheme.textSecondary,
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            bill['source'] == 'manual'
                ? Icons.edit_note
                : Icons.camera_alt_outlined,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bill['source'] == 'manual' ? 'Manual Entry' : 'Scanned Bill',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                bill['created_at']?.toString().substring(0, 10) ?? '',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(bill['status']).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            bill['status'] ?? '',
            style: TextStyle(
              fontSize: 11,
              color: _statusColor(bill['status']),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Bill Scanner Screen ───────────────────────────────────────────────────────

class BillScannerScreen extends StatefulWidget {
  const BillScannerScreen({super.key});
  @override
  State<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends State<BillScannerScreen> {
  File? _image;
  bool _uploading = false;
  String? _status;

  Future<void> _pickImage(ImageSource src) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: src, imageQuality: 85);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _upload() async {
    if (_image == null) return;
    setState(() {
      _uploading = true;
      _status = null;
    });
    try {
      final auth = context.read<AuthService>();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(_image!.path),
        if (auth.storeId != null) 'storeId': auth.storeId,
      });
      await ApiClient.instance.dio.post(
        '/bills/upload',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );
      setState(
        () => _status = 'Uploaded! OCR processing started in background.',
      );
    } catch (e) {
      setState(() => _status = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Bill')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: AppTheme.textSecondary,
                        size: 64,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_image!, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() => _image = null),
                        child: const Text('Change Image'),
                      ),
                    ],
                  ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status!.startsWith('Error')
                    ? AppTheme.error.withOpacity(0.15)
                    : AppTheme.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status!,
                style: TextStyle(
                  color: _status!.startsWith('Error')
                      ? AppTheme.error
                      : AppTheme.success,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: (_image == null || _uploading) ? null : _upload,
            child: _uploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Upload & Extract'),
          ),
        ],
      ),
    ),
  );
}

// ── Bill Manual Entry Screen ──────────────────────────────────────────────────

class BillManualEntryScreen extends StatefulWidget {
  const BillManualEntryScreen({super.key});
  @override
  State<BillManualEntryScreen> createState() => _BillManualEntryScreenState();
}

class _BillManualEntryScreenState extends State<BillManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;

  final List<Map<String, TextEditingController>> _items = [];

  void _addItem() => setState(
    () => _items.add({
      'name': TextEditingController(),
      'qty': TextEditingController(text: '1'),
      'price': TextEditingController(),
    }),
  );

  void _removeItem(int i) => setState(() {
    for (var c in _items[i].values) {
      c.dispose();
    }
    _items.removeAt(i);
  });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final lineItems = _items
          .map(
            (item) => {
              'name': item['name']!.text,
              'qty': double.tryParse(item['qty']!.text) ?? 1,
              'unitPrice': double.tryParse(item['price']!.text) ?? 0,
            },
          )
          .toList();

      await ApiClient.instance.dio.post(
        '/bills/manual',
        data: {
          'storeId': auth.storeId,
          'merchant': _merchantCtrl.text.trim(),
          'date': _date.toIso8601String(),
          'total': double.tryParse(_totalCtrl.text) ?? 0,
          'lineItems': lineItems,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill added successfully!')),
        );
        context.pop();
      }
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
    appBar: AppBar(title: const Text('Manual Bill Entry')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _merchantCtrl,
            decoration: const InputDecoration(
              labelText: 'Merchant / Store Name',
              prefixIcon: Icon(Icons.store_outlined),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.calendar_today_outlined,
              color: AppTheme.primary,
            ),
            title: Text('Date: ${_date.toLocal().toString().substring(0, 10)}'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _totalCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Total Amount (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Line Items',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ],
          ),
          ..._items.asMap().entries.map(
            (e) => _LineItemRow(
              index: e.key,
              controllers: e.value,
              onRemove: () => _removeItem(e.key),
            ),
          ),
          const SizedBox(height: 24),
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
                : const Text('Save Bill'),
          ),
        ],
      ),
    ),
  );
}

class _LineItemRow extends StatelessWidget {
  final int index;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onRemove;
  const _LineItemRow({
    required this.index,
    required this.controllers,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              'Item ${index + 1}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 18, color: AppTheme.error),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controllers['name'],
          decoration: const InputDecoration(
            labelText: 'Product Name',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers['qty'],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controllers['price'],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unit Price',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
