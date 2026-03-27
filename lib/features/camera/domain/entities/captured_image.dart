import 'package:equatable/equatable.dart';

class CapturedImage extends Equatable {
  const CapturedImage({
    required this.path,
    required this.capturedAt,
    this.width,
    this.height,
  });

  final String path;
  final DateTime capturedAt;
  final int? width;
  final int? height;

  @override
  List<Object?> get props => [path, capturedAt, width, height];
}
