import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});

class ImageService {
  final _picker = ImagePicker();

  Future<Uint8List?> pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }

  Future<Uint8List?> pickFromGallery() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }

  /// Compress and resize image to target dimensions
  Uint8List compressImage(Uint8List bytes, {int maxSize = 512}) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final resized = img.copyResize(
      image,
      width: image.width > image.height ? maxSize : null,
      height: image.height >= image.width ? maxSize : null,
    );

    return Uint8List.fromList(img.encodePng(resized));
  }

  /// Create a thumbnail version
  Uint8List createThumbnail(Uint8List bytes, {int size = 200}) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    final thumb = img.copyResizeCropSquare(image, size: size);
    return Uint8List.fromList(img.encodePng(thumb));
  }
}
