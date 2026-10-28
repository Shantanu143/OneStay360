// lib/presentation/common/device_actions.dart
//
// Things screens ask the phone to do: dial, open a link or an app, share,
// copy. Provided through Provider so widget tests can record them.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/components/app_chips.dart';
import '../design/components/app_dialogs.dart';
import 'phone_format.dart';

const supportEmail = 'support@onestay360.brandedpatil.in';
const termsUrl = 'https://onestay360.brandedpatil.in/terms';
const privacyUrl = 'https://onestay360.brandedpatil.in/privacy';

class DeviceActions {
  const DeviceActions();

  /// Opens [uri] outside the app. False when nothing could handle it.
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> share(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  static DeviceActions of(BuildContext context) {
    try {
      return context.read<DeviceActions>();
    } on ProviderNotFoundException {
      return const DeviceActions();
    }
  }
}

/// Opens the dialer for [phone]; says so when there is nothing to dial.
Future<void> dialPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) {
    showAppToast(context, 'No phone number available.');
    return;
  }
  final opened = await DeviceActions.of(context).open(Uri(scheme: 'tel', path: number));
  if (!opened && context.mounted) {
    showAppToast(context, "Couldn't open the dialer.", tone: AppTone.danger);
  }
}

/// Starts a WhatsApp chat with [phone], with [message] typed in.
Future<void> openWhatsApp(BuildContext context, String phone, {String message = ''}) async {
  final number = whatsAppNumber(phone);
  if (number == null) {
    showAppToast(context, 'No WhatsApp number available.');
    return;
  }
  final uri = Uri.parse('https://wa.me/$number${message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}'}');
  final opened = await DeviceActions.of(context).open(uri);
  if (!opened && context.mounted) {
    showAppToast(context, "Couldn't open WhatsApp.", tone: AppTone.danger);
  }
}

/// Opens [uri] in the app that handles it (browser, Maps, mail).
Future<void> openExternal(BuildContext context, Uri uri) async {
  final opened = await DeviceActions.of(context).open(uri);
  if (!opened && context.mounted) {
    showAppToast(context, "Couldn't open that link.", tone: AppTone.danger);
  }
}

Future<void> openMaps(BuildContext context, String query) => openExternal(
      context,
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}'),
    );

Future<void> copyText(BuildContext context, String text, {String? message}) async {
  await DeviceActions.of(context).copy(text);
  if (context.mounted) showAppToast(context, message ?? 'Copied');
}

/// A UPI intent link (`upi://pay?...`) any UPI app opens with the amount filled.
Uri upiPayUri({required String upiId, required String payee, required double amount, required String note}) {
  return Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: {
      'pa': upiId,
      'pn': payee,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': note,
    },
  );
}
