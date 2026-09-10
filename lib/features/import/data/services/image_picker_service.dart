import 'package:image_picker/image_picker.dart';

/// Abstract service interface for picking screenshot images from the device.
abstract class ImagePickerService {
  /// Allows the user to select one or multiple screenshot images from gallery.
  Future<List<String>> pickScreenshots();
}

/// Production implementation of [ImagePickerService] backed by [ImagePicker].
class ImagePickerServiceImpl implements ImagePickerService {
  final ImagePicker _picker;

  ImagePickerServiceImpl([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  @override
  Future<List<String>> pickScreenshots() async {
    try {
      final xFiles = await _picker.pickMultiImage(imageQuality: 90);
      return xFiles.map((x) => x.path).toList();
    } catch (_) {
      // Gracefully handle cancellation or permission denial
      return const [];
    }
  }
}
