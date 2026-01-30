import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/business_state_provider.dart';
import '../../services/team_invitation_service.dart';
import 'widgets/business_scaffold.dart';
import '../../utils/permissions.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _role = 'manager';
  final Set<String> _selectedProperties = {};
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadProperties(String businessId) async {
    final snap = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .get();
    return snap.docs;
  }

  Future<Set<String>> _loadMemberAccess(String businessId, String memberUid) async {
    final propsSnap = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .get();
    final selected = <String>{};
    for (final doc in propsSnap.docs) {
      final accessSnap = await doc.reference.collection('access').doc(memberUid).get();
      if (accessSnap.exists) selected.add(doc.id);
    }
    return selected;
  }

  Future<void> _submitInvite() async {
    final businessId = context.read<BusinessStateProvider>().businessId;
    if (businessId == null || businessId.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final service = context.read<TeamInvitationService>();
      final result = await service.createInvitation(
        businessId: businessId,
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        role: _role,
        propertyIds: _selectedProperties.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent. Link: ${result['inviteLink']}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream(String businessId) {
    return FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('members')
        .snapshots();
  }

  Future<void> _openInviteSheet(List<QueryDocumentSnapshot<Map<String, dynamic>>> props) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite a teammate', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Phone (E.164)'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email (optional)'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                      DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    ],
                    onChanged: (val) => setState(() => _role = val ?? 'manager'),
                  ),
                  const SizedBox(height: 12),
                  Text('Assign properties', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...props.map((doc) {
                    final id = doc.id;
                    final name = doc.data()['name'] as String? ?? id;
                    final selected = _selectedProperties.contains(id);
                    return CheckboxListTile(
                      title: Text(name),
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedProperties.add(id);
                          } else {
                            _selectedProperties.remove(id);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : () async {
                        await _submitInvite();
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Send Invitation'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessId = context.watch<BusinessStateProvider>().businessId;
    final role = context.watch<BusinessStateProvider>().role;
    final bizPerms = BusinessPermissions.fromRole(role);
    return BusinessScaffold(
      currentTab: BusinessTab.team,
      businessId: businessId,
      titleText: 'Team',
      body: businessId == null || businessId.isEmpty
          ? const Center(child: Text('Missing business'))
          : !bizPerms.canInviteMembers
              ? const Center(child: Text('You do not have permission to invite team members.'))
          : FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: _loadProperties(businessId),
              builder: (context, snapshot) {
                final props = snapshot.data ?? [];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Team', style: Theme.of(context).textTheme.titleLarge),
                          FilledButton.icon(
                            onPressed: props.isEmpty
                                ? null
                                : () {
                                    _openInviteSheet(props);
                                  },
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Add member'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _membersStream(businessId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final members = snap.data?.docs ?? [];
                          if (members.isEmpty) {
                            return const Text('No members yet. Tap "Add member" to invite.');
                          }
                          return Column(
                            children: members.map((doc) {
                              final data = doc.data();
                              final display = (data['name'] as String?) ??
                                  (data['displayName'] as String?) ??
                                  (data['email'] as String?) ??
                                  (data['phone'] as String?) ??
                                  doc.id;
                              final roleLabel = data['role'] ?? 'unknown';
                              final status = data['status'] ?? 'pending';
                              return Card(
                                child: ListTile(
                                  title: Text(display),
                                  subtitle: Text('Role: $roleLabel · Status: $status'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => MemberDetailScreen(
                                          businessId: businessId,
                                          member: {...data, 'uid': doc.id},
                                          props: props,
                                          loadAccess: _loadMemberAccess,
                                        ),
                                      ),
                                    );
                                                                    },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class MemberDetailScreen extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> member;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> props;
  final Future<Set<String>> Function(String businessId, String memberUid) loadAccess;

  const MemberDetailScreen({
    super.key,
    required this.businessId,
    required this.member,
    required this.props,
    required this.loadAccess,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late String _role;
  late bool _isOwner;
  Set<String> _selectedProps = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rawRole = (widget.member['role'] as String? ?? '').toLowerCase();
    _isOwner = rawRole == 'owner';
    _role = _isOwner ? 'owner' : (rawRole.isEmpty ? 'staff' : rawRole);
    _initAccess();
  }

  Future<void> _initAccess() async {
    final uid = widget.member['uid'] as String? ?? '';
    if (uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final access = await widget.loadAccess(widget.businessId, uid);
    if (!mounted) return;
    setState(() {
      _selectedProps = access;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_isOwner || _saving) return;
    setState(() => _saving = true);
    try {
      final service = context.read<TeamInvitationService>();
      await service.updateMemberPropertyAccess(
        businessId: widget.businessId,
        memberUid: widget.member['uid'] as String,
        role: _role,
        propertyIds: _selectedProps.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access updated')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update access: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberUid = widget.member['uid'] as String? ?? '';
    final name = (widget.member['name'] as String?) ??
        (widget.member['displayName'] as String?) ??
        (widget.member['email'] as String?) ??
        (widget.member['phone'] as String?) ??
        memberUid;
    final phone = widget.member['phone'] as String?;
    final email = widget.member['email'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    return BusinessScaffold(
      currentTab: BusinessTab.team,
      businessId: widget.businessId,
      titleText: 'Member details',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Card(
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (phone != null) Text('Phone: $phone'),
                          if (email != null) ...[
                            if (phone != null) const SizedBox(height: 4),
                            Text('Email: $email'),
                          ],
                          if (phone == null && email == null)
                            const Text('No contact details available'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isOwner)
                    const Text('Role: Owner (cannot be changed)', style: TextStyle(fontWeight: FontWeight.w600))
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      ],
                      onChanged: (val) => setState(() => _role = val ?? 'staff'),
                    ),
                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Text('Assign properties', style: Theme.of(context).textTheme.titleMedium),
                          ),
                          ...widget.props.map((doc) {
                            final id = doc.id;
                            final pname = doc.data()['name'] as String? ?? id;
                            final selected = _selectedProps.contains(id);
                            return CheckboxListTile(
                              title: Text(pname),
                              value: selected,
                              onChanged: _isOwner
                                  ? null
                                  : (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedProps.add(id);
                                        } else {
                                          _selectedProps.remove(id);
                                        }
                                      });
                                    },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isOwner ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : _isOwner
                              ? const Text('Owner access locked')
                              : const Text('Save access'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
