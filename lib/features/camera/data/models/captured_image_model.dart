import '../../domain/entities/captured_image.dart';

class CapturedImageModel {
  const CapturedImageModel({
    required this.path,
    required this.capturedAt,
    this.width,
    this.height,
  });

  final String path;
  final String capturedAt;
  final int? width;
  final int? height;

  CapturedImage toDomain() => CapturedImage(
        path: path,
        capturedAt: DateTime.parse(capturedAt),
        width: width,
        height: height,
      );
}
