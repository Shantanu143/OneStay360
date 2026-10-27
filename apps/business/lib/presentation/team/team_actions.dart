// lib/presentation/team/team_actions.dart
import 'package:flutter/material.dart';

import '../common/device_actions.dart';
import '../views/home/home_sheets.dart' show whatsappNumber;

/// Where invitation links point; the app opens them from this host.
const inviteBaseUrl = 'https://app.onestay360.brandedpatil.in';

String inviteLinkFor(String inviteId) => '$inviteBaseUrl/invite?inviteId=$inviteId';

/// A WhatsApp chat with [phone] with the invitation ready to send; without a
/// usable number, a "pick a chat" share link.
Uri whatsappInviteLink(String? phone, String link, {String? businessName}) {
  final text = "You're invited to join ${businessName ?? 'our team'} on OneStay360. Open this link to accept: $link";
  final number = phone == null ? null : whatsappNumber(phone);
  return Uri.https('wa.me', number == null ? '/' : '/$number', {'text': text});
}

/// What the team screens ask of the phone. Faked in tests.
abstract class TeamActions {
  Future<void> copy(BuildContext context, String text, {String? message});

  Future<void> openUrl(BuildContext context, Uri uri);

  Future<void> call(BuildContext context, String phone);
}

class DeviceTeamActions implements TeamActions {
  const DeviceTeamActions();

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) =>
      copyText(context, text, message: message);

  @override
  Future<void> openUrl(BuildContext context, Uri uri) => openExternal(context, uri);

  @override
  Future<void> call(BuildContext context, String phone) => dialPhone(context, phone);
}
