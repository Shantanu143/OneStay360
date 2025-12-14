import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<List<String>> uploadPropertyImages(List<XFile> images, String propertyId) async {
    final List<String> urls = [];

    try {
      if (propertyId.isEmpty) {
        throw ArgumentError('Property ID cannot be empty');
      }

      for (final image in images) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'image_${timestamp}_${images.indexOf(image)}.jpg';

        final ref = _storage.ref()
            .child('property_images')
            .child(propertyId)
            .child(fileName);

        try {
          final fileData = await image.readAsBytes();

          final uploadTask = ref.putData(
            fileData,
            SettableMetadata(
              contentType: 'image/jpeg',
            ),
          );

          final snapshot = await uploadTask;
          final url = await snapshot.ref.getDownloadURL();
          urls.add(url);

          print('Successfully uploaded image: $url');

        } on FirebaseException catch (e) {
          print('Firebase Storage Error: ${e.code} - ${e.message}');
          // Continue with other images instead of failing completely
          continue;
        }
      }
    } catch (e) {
      print('Error in uploadPropertyImages: $e');
      // Don't rethrow, return whatever URLs were successfully uploaded
    }

    return urls;
  }



  Future<List<XFile>> pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return pickedFiles;
    } catch (e) {
      print('Error picking images: $e');
      rethrow;
    }
  }

  // Add method to delete images
  Future<void> deleteImages(List<String> imageUrls) async {
    try {
      for (final url in imageUrls) {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      }
    } catch (e) {
      print('Error deleting images: $e');
      rethrow;
    }
  }

  // Upload tenant document
  Future<String> uploadTenantDocument(XFile file, String tenantId, String documentType) async {
    try {
      if (tenantId.isEmpty) {
        throw ArgumentError('Tenant ID cannot be empty');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.name.split('.').last;
      final fileName = '${documentType}_$timestamp.$extension';

      final ref = _storage.ref()
          .child('tenant_documents')
          .child(tenantId)
          .child(fileName);

      final fileData = await file.readAsBytes();
      
      // Determine content type based on extension
      String contentType = 'application/octet-stream';
      if (extension.toLowerCase() == 'pdf') {
        contentType = 'application/pdf';
      } else if (['jpg', 'jpeg', 'png'].contains(extension.toLowerCase())) {
        contentType = 'image/$extension';
      }

      final uploadTask = ref.putData(
        fileData,
        SettableMetadata(contentType: contentType),
      );

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      print('Successfully uploaded document: $url');
      return url;
    } catch (e) {
      print('Error uploading tenant document: $e');
      rethrow;
    }
  }

  // Pick single image or file
  Future<XFile?> pickSingleImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return pickedFile;
    } catch (e) {
      print('Error picking image: $e');
      rethrow;
    }
  }

  // Pick single file (for PDFs)
  Future<XFile?> pickSingleFile() async {
    try {
      // For now, we'll use image picker. For PDFs, you might need file_picker package
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return pickedFile;
    } catch (e) {
      print('Error picking file: $e');
      rethrow;
    }
  }
}
