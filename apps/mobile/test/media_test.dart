import 'dart:typed_data';

import 'package:dopmi_mobile/core/media/media_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test(
    'photo policies share normalization and never accept a PDF as a photo',
    () {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 20, height: 20)),
      );
      for (final purpose in [
        MediaPurpose.adoptionPhoto,
        MediaPurpose.rescuePhoto,
      ]) {
        final result = prepareMedia((purpose, bytes));
        expect(result.contentType, 'image/jpeg');
        expect(result.extension, 'jpg');
        expect(img.decodeJpg(result.bytes), isNotNull);
        expect(
          () =>
              prepareMedia((purpose, Uint8List.fromList('%PDF-1.7'.codeUnits))),
          throwsFormatException,
        );
      }
    },
  );

  test('documents retain bytes but require PDF signature and the evidence size limit', () {
    final pdf = Uint8List.fromList('%PDF-1.7\n%%EOF'.codeUnits);
    final result = prepareMedia((MediaPurpose.rescueDocument, pdf));
    expect(result.bytes, pdf);
    expect(result.contentType, 'application/pdf');
    expect(
      () => prepareMedia((MediaPurpose.rescueDocument, Uint8List(12))),
      throwsFormatException,
    );
    expect(
      () => prepareMedia((
        MediaPurpose.rescueDocument,
        Uint8List(5 * 1024 * 1024 + 1),
      )),
      throwsFormatException,
    );
    expect(
      () => prepareMedia((
        MediaPurpose.rescuePhoto,
        Uint8List(5 * 1024 * 1024 + 1),
      )),
      throwsFormatException,
    );
  });
}
