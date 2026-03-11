import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:nsfw_detector_flutter/nsfw_detector_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageValidationResult {
  final bool isValid;
  final String? errorMessage;

  ImageValidationResult({required this.isValid, this.errorMessage});

  factory ImageValidationResult.success() => ImageValidationResult(isValid: true);
  factory ImageValidationResult.failure(String message) =>
      ImageValidationResult(isValid: false, errorMessage: message);
}

class ImageValidationService {
  static final ImageValidationService _instance = ImageValidationService._internal();
  factory ImageValidationService() => _instance;
  ImageValidationService._internal();

  FaceDetector? _faceDetector;
  NsfwDetector? _nsfwDetector;

  Future<void> initialize() async {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      _nsfwDetector = await NsfwDetector.load(threshold: 0.5);
    } catch (e) {
      debugPrint("Error initializing ImageValidationService: $e");
    }
  }

  Future<ImageValidationResult> validateImage(File file, int index) async {
    // 1. Resolution Check (Always required)
    final resolutionResult = await checkResolution(file);
    if (!resolutionResult.isValid) return resolutionResult;

    // 2. Explicit Content Detection (Always required)
    final explicitResult = await checkExplicitContent(file);
    if (!explicitResult.isValid) return explicitResult;

    // 2.5 Text & Contact Info Detection (Always required)
    final textModerationResult = await checkTextModeration(file);
    if (!textModerationResult.isValid) return textModerationResult;

    // 3. Face Detection (Required for the first two pictures only)
    if (index < 2) {
      final faceResult = await checkFaceDetection(file, requireSingleFace: true);
      if (!faceResult.isValid) return faceResult;
    }

    return ImageValidationResult.success();
  }

  Future<ImageValidationResult> checkResolution(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        return ImageValidationResult.failure("Invalid image file format.");
      }

      const int minWidth = 600;
      const int minHeight = 600;

      if (image.width < minWidth || image.height < minHeight) {
        return ImageValidationResult.failure(
            "Image resolution is too low (${image.width}x${image.height}). Minimum required is ${minWidth}x${minHeight}px.");
      }

      return ImageValidationResult.success();
    } catch (e) {
      return ImageValidationResult.failure("Error checking image resolution: $e");
    }
  }

  Future<ImageValidationResult> checkFaceDetection(File file, {bool requireSingleFace = false}) async {
    try {
      if (_faceDetector == null) await initialize();
      
      final inputImage = InputImage.fromFile(file);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        return ImageValidationResult.failure(
            "No face detected. Your first two profile pictures must clearly show your face.");
      }

      if (requireSingleFace && faces.length > 1) {
        return ImageValidationResult.failure(
            "More than one face detected. The first two pictures should only feature you.");
      }

      return ImageValidationResult.success();
    } catch (e) {
      return ImageValidationResult.failure("Face detection error: $e");
    }
  }

  Future<ImageValidationResult> checkExplicitContent(File file) async {
    try {
      if (_nsfwDetector == null) await initialize();
      if (_nsfwDetector == null) return ImageValidationResult.success(); // Fallback if init fails
      
      final result = await _nsfwDetector!.detectNSFWFromFile(file);
      final isNSFW = result?.isNsfw ?? false;
      
      if (isNSFW) {
        return ImageValidationResult.failure(
            "Upload blocked: This image contains adult or explicit content (nudes/pornographic material) which is not allowed.");
      }

      return ImageValidationResult.success();
    } catch (e) {
      debugPrint("NSFW Check Error: $e");
      // If detection fails (e.g. model error), we'll allow it but log it
      return ImageValidationResult.success(); 
    }
  }

  Future<ImageValidationResult> checkTextModeration(File file) async {
    // 🔴 IMPORTANT: Replace with your current Ngrok URL!
    final String serverUrl = 'https://nina-unpumped-linus.ngrok-free.dev/moderate_image';
    
    // Skip if URL is not set or is still the placeholder tutorial text
    if (serverUrl.isEmpty || serverUrl.contains("YOUR_NGROK_URL")) {
      return ImageValidationResult.success();
    }

    try {
      debugPrint("📤 Sending image to Python server for scan: $serverUrl");
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      
      var streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        
        if (data['status'] == 'rejected') {
          return ImageValidationResult.failure(
              "Blocked: Images with text, numbers, or handles are not allowed.");
        }
      }
      return ImageValidationResult.success();
    } catch (e) {
      debugPrint("Moderation Connection Error: $e");
      return ImageValidationResult.success(); // Let it pass if server is down/offline
    }
  }

  void dispose() {
    _faceDetector?.close();
  }
}
