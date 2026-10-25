import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class RecordPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> tenant;
  final String businessId;

  const RecordPaymentScreen({
    super.key,
    required this.tenant,
    required this.businessId,
  });

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _txnIdCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _paymentMode = 'Cash';
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  bool _isLoading = false;

  static const _modes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'];

  List<String> _monthOptions() {
    final months = <String>[];
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MMMM yyyy').format(d));
    }
    return months;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final fn = FirebaseFunctions.instance.httpsCallable('recordPayment');
      await fn.call({
        'businessId': widget.businessId,
        'tenantId': widget.tenant['tenantId'] ?? widget.tenant['id'],
        'amount': double.parse(_amountCtrl.text.trim()),
        'month': _selectedMonth,
        'paymentMode': _paymentMode,
        'transactionId': _txnIdCtrl.text.trim().isEmpty ? null : _txnIdCtrl.text.trim(),
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Payment recorded successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // return true so caller can refresh
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.message ?? 'Failed to record payment'}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _txnIdCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rent = widget.tenant['rent'] ?? widget.tenant['monthlyRent'] ?? 0;
    final tenantName = widget.tenant['name'] ?? 'Tenant';
    final room = widget.tenant['room'] ?? '';
    final bed = widget.tenant['bed'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Record Payment',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tenant info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D7377).withOpacity(0.9),
                    const Color(0xFF085D61).withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      tenantName.isNotEmpty ? tenantName[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenantName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Room $room · Bed $bed',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                        ),
                        Text(
                          'Monthly Rent: ₹$rent',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount
            _SectionLabel(label: 'Payment Amount *'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: _inputDecoration(
                hint: 'e.g. ${rent.toString()}',
                prefix: const Text('₹ ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Amount is required';
                if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
                if (double.parse(v.trim()) <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Quick fill
            Row(
              children: [
                for (final pct in [100, 50]) ...[
                  OutlinedButton(
                    onPressed: () {
                      final r = (rent is num) ? rent.toDouble() : double.tryParse(rent.toString()) ?? 0;
                      _amountCtrl.text = (r * pct / 100).toStringAsFixed(0);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D7377),
                      side: const BorderSide(color: Color(0xFF0D7377)),
                    ),
                    child: Text('$pct%'),
                  ),
                  if (pct != 50) const SizedBox(width: 8),
                ],
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _amountCtrl.text = rent.toString(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D7377),
                    side: const BorderSide(color: Color(0xFF0D7377)),
                  ),
                  child: const Text('Full'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Month
            _SectionLabel(label: 'For Month *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedMonth,
              decoration: _inputDecoration(hint: ''),
              items: _monthOptions()
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMonth = v!),
            ),
            const SizedBox(height: 20),

            // Payment mode
            _SectionLabel(label: 'Payment Mode *'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _modes.map((mode) {
                final selected = _paymentMode == mode;
                return ChoiceChip(
                  label: Text(mode),
                  selected: selected,
                  selectedColor: const Color(0xFF0D7377),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _paymentMode = mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Transaction ID (optional)
            _SectionLabel(label: 'Transaction ID (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _txnIdCtrl,
              decoration: _inputDecoration(hint: 'UPI ref / cheque no / etc.'),
            ),
            const SizedBox(height: 16),

            // Note (optional)
            _SectionLabel(label: 'Note (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: _inputDecoration(hint: 'e.g. advance payment, partial, late fee included'),
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7377),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Record Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefix: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0D7377), width: 1.5),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
        letterSpacing: 0.3,
      ),
    );
  }
}
