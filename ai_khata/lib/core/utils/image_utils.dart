import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ImageUtils {
  /// Picks an image. Returns an XFile — works on web, iOS, and Android.
  static Future<XFile?> pickImage({
    required ImageSource source,
    int imageQuality = 85,
    CameraDevice preferredCamera = CameraDevice.rear,
  }) async {
    try {
      final picker = ImagePicker();
      
      final picked = await picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCamera,
      );
      
      if (picked == null) return null;
      
      // Check if it's a HEIC file (by path extension — native only)
      if (picked.path.toLowerCase().contains('.heic') ||
          picked.path.toLowerCase().contains('.heif')) {
        throw PlatformException(
          code: 'unsupported_format',
          message: 'HEIC format detected. Please convert to JPEG or use camera to take a new photo.',
        );
      }

      return picked;
      
    } on PlatformException catch (e) {
      if (e.code == 'invalid_image' || 
          e.message?.contains('public.heic') == true ||
          e.message?.contains('HEIC') == true) {
        throw PlatformException(
          code: 'heic_not_supported',
          message: 'HEIC format is not supported. Please:\n'
              '• Take a new photo with the camera, or\n'
              '• Convert your image to JPEG format, or\n'
              '• Change your iPhone camera settings to save as JPEG',
        );
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Check if a file is likely to be a HEIC format
  static bool isHEICFormat(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.heic') || 
           lowerPath.endsWith('.heif') ||
           lowerPath.contains('heic') ||
           lowerPath.contains('heif');
  }
  
  /// Get user-friendly error message for image picker errors
  static String getImagePickerErrorMessage(dynamic error) {
    if (error is PlatformException) {
      switch (error.code) {
        case 'invalid_image':
        case 'heic_not_supported':
          return error.message ?? 'HEIC format is not supported';
        case 'camera_access_denied':
          return 'Camera access denied. Please enable camera permission in Settings.';
        case 'photo_access_denied':
          return 'Photo library access denied. Please enable photo access permission in Settings.';
        default:
          return error.message ?? 'Failed to select image';
      }
    }
    
    final errorString = error.toString();
    if (errorString.contains('public.heic') || errorString.contains('HEIC')) {
      return 'HEIC format is not supported. Please use JPEG format or take a new photo.';
    }
    
    return 'An error occurred while selecting the image. Please try again.';
  }
  
  /// Show instructions for handling HEIC format
  static String getHEICInstructions() {
    return 'To avoid HEIC format issues:\n\n'
        '1. Take a new photo using the camera button\n'
        '2. Or convert existing HEIC photos to JPEG:\n'
        '   • Open Photos app\n'
        '   • Select the image\n'
        '   • Tap Share → Save to Files\n'
        '   • Choose "JPEG" format\n\n'
        '3. Or change iPhone camera settings:\n'
        '   • Settings → Camera → Formats\n'
        '   • Select "Most Compatible" instead of "High Efficiency"';
  }
}