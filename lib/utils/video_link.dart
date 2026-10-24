import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations_extension.dart';

Uri? parseVideoUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.host.isNotEmpty
      ? uri
      : null;
}

Future<void> openVideoLink(BuildContext context, String url) async {
  final uri = parseVideoUri(url);
  final launched = uri != null &&
      (await launchUrl(uri, mode: LaunchMode.externalApplication) ||
          await launchUrl(uri, mode: LaunchMode.platformDefault));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.couldNotOpenVideoLink)),
    );
  }
}
