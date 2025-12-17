import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ImageConversionService {
  
  InputImage? convertCameraImage(CameraImage image, CameraDescription camera) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final ui.Size imageSize = ui.Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // FIX 1: Calculate correct rotation based on camera sensor
    final InputImageRotation imageRotation = _inputImageRotation(camera);

    // FIX 2: Use NV21 for Android, BGRA8888 for iOS
    final InputImageFormat inputImageFormat = Platform.isAndroid 
        ? InputImageFormat.nv21 
        : InputImageFormat.bgra8888;

    // Verify plane data is available before creating metadata
    if (image.planes.isEmpty) return null;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );

    return inputImage;
  }

  InputImageRotation _inputImageRotation(CameraDescription camera) {
    final int sensorOrientation = camera.sensorOrientation;
    // For this app we are likely using Portrait mode, so we map sensor rotation directly.
    // If you support device rotation (landscape), you need to combine this with 
    // the device orientation.
    return InputImageRotationValue.fromRawValue(sensorOrientation) ?? 
           InputImageRotation.rotation0deg;
  }
}