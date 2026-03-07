import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/tenant_scaffold.dart';

class EnrollRequestScreen extends StatefulWidget {
  final String? pgName;
  final String? location;

  const EnrollRequestScreen({
    super.key,
    this.pgName,
    this.location,
  });

  @override
  State<EnrollRequestScreen> createState() => _EnrollRequestScreenState();
}

class _EnrollRequestScreenState extends State<EnrollRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pgNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _roomType = 'PG';
  String _sharing = 'Single';
  DateTime? _moveIn;

  @override
  void initState() {
    super.initState();
    if (widget.pgName != null) _pgNameCtrl.text = widget.pgName!;
    if (widget.location != null) _locationCtrl.text = widget.location!;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _pgNameCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMoveInDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveIn ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _moveIn = picked);
    }
  }

  void _submit() {
    HapticFeedback.lightImpact();
    if (_formKey.currentState?.validate() != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enrollment request sent successfully!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return TenantScaffold(
      currentTab: TenantTab.home,
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _card(
            children: [
              _text('Personal Details', isTitle: true),
              const SizedBox(height: 12),
              _textField(
                controller: _fullNameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Enter valid phone'
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            children: [
              _text('PG Details', isTitle: true),
              const SizedBox(height: 12),
              _textField(
                controller: _pgNameCtrl,
                label: 'PG Name',
                icon: Icons.apartment_outlined,
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _locationCtrl,
                label: 'Location',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                value: _roomType,
                label: 'Accommodation Type',
                icon: Icons.home_work_outlined,
                items: const ['PG', 'Hostel', 'Flat'],
                onChanged: (v) => setState(() => _roomType = v ?? _roomType),
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                value: _sharing,
                label: 'Sharing Preference',
                icon: Icons.group_outlined,
                items: const ['Single', 'Double', 'Triple'],
                onChanged: (v) => setState(() => _sharing = v ?? _sharing),
              ),
              const SizedBox(height: 12),
              _dateField(
                label: 'Preferred Move-in',
                icon: Icons.event_outlined,
                value: _moveIn,
                onTap: _pickMoveInDate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _card(
            children: [
              _text('Additional Notes', isTitle: true),
              const SizedBox(height: 12),
              _textField(
                controller: _noteCtrl,
                label: 'Write any special requests...',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _text(String s, {bool isTitle = false}) {
    return Text(
      s,
      style: TextStyle(
        fontSize: isTitle ? 18 : 14,
        fontWeight: isTitle ? FontWeight.bold : FontWeight.w600,
        color: const Color(0xFF164e63),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF06B6D4)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF06B6D4)),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF06B6D4)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem<T>(
            value: e,
            child: Text(e.toString()),
          ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required IconData icon,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final text = value != null
        ? '${value.day}/${value.month}/${value.year}'
        : 'Choose a date';
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF06B6D4)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(text),
      ),
    );
  }
}
