// lib/presentation/common/device_actions.dart
//
// Things screens ask the phone to do: dial, open a link, copy text.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';

/// Opens the dialer for [phone]; says so when there is nothing to dial.
Future<void> dialPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) {
    showBizToast(context, 'No phone number available.');
    return;
  }
  final opened = await launchUrl(Uri(scheme: 'tel', path: number));
  if (!opened && context.mounted) {
    showBizToast(context, "Couldn't open the dialer.", tone: BizTone.danger);
  }
}

/// Opens [uri] in the app that handles it (browser, WhatsApp, Maps).
Future<void> openExternal(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    showBizToast(context, "Couldn't open that link.", tone: BizTone.danger);
  }
}

Future<void> copyText(BuildContext context, String text, {String? message}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showBizToast(context, message ?? 'Copied');
}
