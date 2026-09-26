import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List preparePhoto(Uint8List bytes) {
  if (bytes.length < 16) {
    throw const FormatException(
      'No pudimos abrir esa foto. Elige un archivo JPG, PNG o WebP.',
    );
  }
  if (bytes.length > 15 * 1024 * 1024) {
    throw const FormatException('La foto debe pesar menos de 15 MB.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException(
      'Elige una foto JPG, PNG o WebP de hasta 40 megapíxeles.',
    );
  }
  var photo = decoder!.decodeFrame(0);
  if (photo == null) throw const FormatException('No pudimos abrir esa foto.');
  photo = img.bakeOrientation(photo);
  if (photo.width > 1600 || photo.height > 1600) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1600 : null,
      height: photo.height > photo.width ? 1600 : null,
    );
  }
  // Copy pixels into a clean image so EXIF, location, comments and other metadata are not uploaded.
  final clean = img.Image.fromBytes(
    width: photo.width,
    height: photo.height,
    bytes: photo.getBytes(order: img.ChannelOrder.rgb).buffer,
    numChannels: 3,
  );
  return Uint8List.fromList(img.encodeJpg(clean, quality: 85));
}
