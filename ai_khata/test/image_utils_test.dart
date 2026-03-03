import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_khata/core/utils/image_utils.dart';

void main() {
  group('ImageUtils Tests', () {
    test('should detect HEIC format correctly', () {
      expect(ImageUtils.isHEICFormat('/path/to/image.heic'), true);
      expect(ImageUtils.isHEICFormat('/path/to/image.HEIC'), true);
      expect(ImageUtils.isHEICFormat('/path/to/image.heif'), true);
      expect(ImageUtils.isHEICFormat('/path/to/image.HEIF'), true);
      expect(ImageUtils.isHEICFormat('/path/to/image.jpg'), false);
      expect(ImageUtils.isHEICFormat('/path/to/image.jpeg'), false);
      expect(ImageUtils.isHEICFormat('/path/to/image.png'), false);
    });

    test('should return correct error message for HEIC format', () {
      final heicError = PlatformException(
        code: 'invalid_image', 
        message: 'Cannot load representation of type public.heic'
      );
      
      final message = ImageUtils.getImagePickerErrorMessage(heicError);
      expect(message, 'Cannot load representation of type public.heic');
    });
    
    test('should return correct error message for camera access denied', () {
      final cameraError = PlatformException(
        code: 'camera_access_denied', 
        message: 'Camera access denied'
      );
      
      final message = ImageUtils.getImagePickerErrorMessage(cameraError);
      expect(message, contains('Camera access denied'));
      expect(message, contains('Settings'));
    });
    
    test('should return correct error message for photo access denied', () {
      final photoError = PlatformException(
        code: 'photo_access_denied', 
        message: 'Photo library access denied'
      );
      
      final message = ImageUtils.getImagePickerErrorMessage(photoError);
      expect(message, contains('Photo library access denied'));
      expect(message, contains('Settings'));
    });
    
    test('should return HEIC instructions', () {
      final instructions = ImageUtils.getHEICInstructions();
      expect(instructions, contains('Take a new photo'));
      expect(instructions, contains('convert'));
      expect(instructions, contains('Settings'));
      expect(instructions, contains('Most Compatible'));
    });
  });
}