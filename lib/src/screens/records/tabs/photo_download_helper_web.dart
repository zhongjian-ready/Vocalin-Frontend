// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> savePhotoFromUrlImpl(
  String imageUrl, {
  String? suggestedFileName,
}) async {
  final anchor = html.AnchorElement(href: imageUrl)
    ..download = suggestedFileName ?? 'image'
    ..target = '_blank'
    ..rel = 'noopener noreferrer';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
