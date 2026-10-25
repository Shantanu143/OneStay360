import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_pin_sheet.dart';

class PinboardWidget extends StatelessWidget {
  final String propertyId;
  const PinboardWidget({super.key, required this.propertyId});

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final difference = DateTime.now().difference(timestamp.toDate());
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'sports':
        return const Color(0xFFE0F2FE); // Soft Blue
      case 'lost_found':
        return const Color(0xFFF3E8FF); // Soft Purple
      case 'marketplace':
        return const Color(0xFFDCFCE7); // Soft Green
      case 'social':
      default:
        return const Color(0xFFFFFBEB); // Soft Amber/Yellow
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'sports':
        return '🏸';
      case 'lost_found':
        return '🔑';
      case 'marketplace':
        return '📦';
      case 'social':
      default:
        return '☕';
    }
  }

  Future<void> _handleNoteTap(BuildContext context, Map<String, dynamic> note) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final isAuthor = note['authorId'] == currentUser.uid;
    final noteId = note['noteId'] as String;

    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAuthor ? 'Manage Your Pin 📌' : 'Reply to ${note['authorName']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAuthor 
              ? 'Would you like to remove this note from the Pinboard?' 
              : 'You can chat with ${note['authorName']} directly via WhatsApp regarding: "${note['content']}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          if (isAuthor)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                try {
                  await FirebaseFirestore.instance.collection('pinboard').doc(noteId).delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Delete'),
            )
          else
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final phone = note['authorPhone']?.toString() ?? '';
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact details unavailable for this author')),
                  );
                  return;
                }

                // Format phone number with country code for WhatsApp link
                String formattedPhone = phone.replaceAll(RegExp(r'\D'), '');
                if (formattedPhone.length == 10) {
                  formattedPhone = '91$formattedPhone';
                }

                final content = note['content']?.toString() ?? '';
                final message = 'Hi, I saw your note on OneStay360 Pinboard: "$content"';
                final whatsappUrl = Uri.parse(
                  'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}'
                );

                try {
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not launch WhatsApp. Copying phone number: $phone')),
                      );
                      Clipboard.setData(ClipboardData(text: phone));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.message, color: Colors.white, size: 18),
              label: const Text('WhatsApp'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final angles = [-1.5, 1.2, -0.8, 1.5]; // Tilting angles for sticky note effect

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'The Pinboard 📌',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                AddPinSheet.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'Pin Note',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pinboard')
              .where('propertyId', isEqualTo: propertyId)
              .where('expiresAt', isGreaterThan: Timestamp.now())
              .orderBy('expiresAt', descending: false) // Expiring soonest first
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.push_pin_outlined, size: 36, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text(
                      'Nothing pinned today',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Pin Note" to share something with roommates.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Limit to max 4 items on home screen
            final displayDocs = docs.take(4).toList();

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.05,
              ),
              itemCount: displayDocs.length,
              itemBuilder: (context, index) {
                final note = displayDocs[index].data() as Map<String, dynamic>;
                final category = note['category'] ?? 'social';
                final emoji = _getCategoryEmoji(category);
                final bgColor = _getCategoryColor(category);
                final rotationAngle = angles[index % angles.length];

                return Transform.rotate(
                  angle: rotationAngle * 3.14159 / 180,
                  child: GestureDetector(
                    onTap: () => _handleNoteTap(context, note),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.black.withOpacity(0.04),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              Text(
                                _formatTime(note['createdAt'] as Timestamp?),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              note['content'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                                height: 1.3,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '- ${note['authorName']}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
