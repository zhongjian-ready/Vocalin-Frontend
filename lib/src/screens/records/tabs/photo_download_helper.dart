import 'photo_download_helper_stub.dart'
    if (dart.library.html) 'photo_download_helper_web.dart';

Future<bool> savePhotoFromUrl(
  String imageUrl, {
  String? suggestedFileName,
}) {
  return savePhotoFromUrlImpl(
    imageUrl,
    suggestedFileName: suggestedFileName,
  );
}
