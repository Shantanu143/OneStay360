// Add to your services folder - image_service.dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<List<String>> uploadPropertyImages(List<XFile> images, String propertyId) async {
    final List<String> urls = [];

    for (final image in images) {
      final ref = _storage.ref()
          .child('property_images')
          .child(propertyId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await ref.putData(await image.readAsBytes());
      final url = await uploadTask.ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<List<XFile>> pickImages() async {
    final pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    return pickedFiles;
  }
}