import 'photo_store.dart';
import 'photo_store_web.dart'
    if (dart.library.io) 'photo_store_io.dart'
    as platform;

PhotoStore createPhotoStore() => platform.createPhotoStore();
