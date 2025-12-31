import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

class ImageHighlightScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> mappings;
  final List<Map<String, dynamic>>? healthWarnings;

  const ImageHighlightScreen({
    super.key,
    required this.imagePath,
    required this.mappings,
    this.healthWarnings,
  });

  @override
  State<ImageHighlightScreen> createState() => _ImageHighlightScreenState();
}

class _ImageHighlightScreenState extends State<ImageHighlightScreen> {
  ui.Image? _image;
  Size? _imageSize;
  Size? _displaySize;
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  Offset _offset = Offset.zero;
  bool _isLoading = true;
  bool _useOrientationFix = true;
  int? _originalExifOrientation;
  bool _orientationWasFixed = false;
  bool _isCameraImage = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();

      _isCameraImage = widget.imagePath.contains('image_picker') &&
                       widget.imagePath.contains('tmp');
      Uint8List imageBytes = bytes;
      int? originalWidth, originalHeight;
      int? fixedWidth, fixedHeight;

      if (_useOrientationFix) {
        img.Image? decodedImage = img.decodeImage(bytes);

        if (decodedImage != null) {
          originalWidth = decodedImage.width;
          originalHeight = decodedImage.height;

          try {
            _originalExifOrientation = decodedImage.exif.imageIfd.orientation;
          } catch (e) {
            _originalExifOrientation = null;
          }

          decodedImage = img.bakeOrientation(decodedImage);

          fixedWidth = decodedImage.width;
          fixedHeight = decodedImage.height;

          final orientationChanged = originalWidth != fixedWidth || originalHeight != fixedHeight;
          _orientationWasFixed = orientationChanged || (_originalExifOrientation != null && _originalExifOrientation != 1);

          if (orientationChanged) {
            imageBytes = Uint8List.fromList(img.encodePng(decodedImage));
          } else if (_originalExifOrientation != null && _originalExifOrientation != 1) {
            imageBytes = Uint8List.fromList(img.encodePng(decodedImage));
          }
        }
      }

      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();

      setState(() {
        _image = frame.image;
        _imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    }
  }

  void _calculateScale(Size displaySize) {
    if (_imageSize == null) return;

    final imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final displayAspectRatio = displaySize.width / displaySize.height;

    if (imageAspectRatio > displayAspectRatio) {
      _scaleX = displaySize.width / _imageSize!.width;
      _scaleY = _scaleX;
      _offset = Offset(0, (displaySize.height - _imageSize!.height * _scaleY) / 2);
    } else {
      _scaleY = displaySize.height / _imageSize!.height;
      _scaleX = _scaleY;
      _offset = Offset((displaySize.width - _imageSize!.width * _scaleX) / 2, 0);
    }

    _displaySize = displaySize;
  }

  List<Rect> _getScaledBoundingBoxes() {
    if (_imageSize == null || _displaySize == null) {
      return [];
    }

    List<Rect> boxes = [];
    for (int i = 0; i < widget.mappings.length; i++) {
      final mapping = widget.mappings[i];
      final boundingBox = mapping['bounding_box'];

      if (boundingBox is List && boundingBox.length >= 4) {
        try {
          double minX = double.infinity;
          double minY = double.infinity;
          double maxX = double.negativeInfinity;
          double maxY = double.negativeInfinity;

          for (int j = 0; j < boundingBox.length; j++) {
            final point = boundingBox[j];
            if (point is List && point.length >= 2) {
              final x = (point[0] as num).toDouble();
              final y = (point[1] as num).toDouble();
              minX = minX < x ? minX : x;
              minY = minY < y ? minY : y;
              maxX = maxX > x ? maxX : x;
              maxY = maxY > y ? maxY : y;
            }
          }

            if (minX != double.infinity && minY != double.infinity) {
            double pixelMinX = 0.0, pixelMinY = 0.0, pixelMaxX = 0.0, pixelMaxY = 0.0;

            if (maxX <= 1.0 && maxY <= 1.0 && _imageSize != null) {
              pixelMinX = minX * _imageSize!.width;
              pixelMinY = minY * _imageSize!.height;
              pixelMaxX = maxX * _imageSize!.width;
              pixelMaxY = maxY * _imageSize!.height;
            } else if (maxX > 1.0 && maxY > 1.0 && _imageSize != null) {
              if (_isCameraImage) {
                pixelMinX = minY;
                pixelMinY = minX;
                pixelMaxX = maxY;
                pixelMaxY = maxX;

                final tempMinX = pixelMinX;
                final tempMaxX = pixelMaxX;
                pixelMinX = _imageSize!.width - tempMaxX;
                pixelMaxX = _imageSize!.width - tempMinX;
              } else {
                if (maxX > _imageSize!.width || maxY > _imageSize!.height) {
                  final scaleX = _imageSize!.width / maxX;
                  final scaleY = _imageSize!.height / maxY;
                  final scale = scaleX < scaleY ? scaleX : scaleY;
                  pixelMinX = minX * scale;
                  pixelMinY = minY * scale;
                  pixelMaxX = maxX * scale;
                  pixelMaxY = maxY * scale;
                } else {
                  pixelMinX = minX;
                  pixelMinY = minY;
                  pixelMaxX = maxX;
                  pixelMaxY = maxY;
                }
              }

              pixelMinX = pixelMinX.clamp(0.0, _imageSize!.width);
              pixelMinY = pixelMinY.clamp(0.0, _imageSize!.height);
              pixelMaxX = pixelMaxX.clamp(0.0, _imageSize!.width);
              pixelMaxY = pixelMaxY.clamp(0.0, _imageSize!.height);

              if (_orientationWasFixed && _originalExifOrientation != null) {

                double adjustedMinX, adjustedMinY, adjustedMaxX, adjustedMaxY;

                switch (_originalExifOrientation) {
                  case 3:
                    adjustedMinX = _imageSize!.width - pixelMaxX;
                    adjustedMinY = _imageSize!.height - pixelMaxY;
                    adjustedMaxX = _imageSize!.width - pixelMinX;
                    adjustedMaxY = _imageSize!.height - pixelMinY;
                    break;
                  case 6:
                    adjustedMinX = pixelMinY;
                    adjustedMinY = _imageSize!.width - pixelMaxX;
                    adjustedMaxX = pixelMaxY;
                    adjustedMaxY = _imageSize!.width - pixelMinX;
                    break;
                  case 8:
                    adjustedMinX = _imageSize!.height - pixelMaxY;
                    adjustedMinY = pixelMinX;
                    adjustedMaxX = _imageSize!.height - pixelMinY;
                    adjustedMaxY = pixelMaxX;
                    break;
                  default:
                    adjustedMinX = pixelMinX;
                    adjustedMinY = pixelMinY;
                    adjustedMaxX = pixelMaxX;
                    adjustedMaxY = pixelMaxY;
                }

                pixelMinX = adjustedMinX;
                pixelMinY = adjustedMinY;
                pixelMaxX = adjustedMaxX;
                pixelMaxY = adjustedMaxY;

                pixelMinX = pixelMinX.clamp(0.0, _imageSize!.width);
                pixelMinY = pixelMinY.clamp(0.0, _imageSize!.height);
                pixelMaxX = pixelMaxX.clamp(0.0, _imageSize!.width);
                pixelMaxY = pixelMaxY.clamp(0.0, _imageSize!.height);
              }
            } else {
              if (_imageSize != null) {
                pixelMinX = minX * _imageSize!.width;
                pixelMinY = minY * _imageSize!.height;
                pixelMaxX = maxX * _imageSize!.width;
                pixelMaxY = maxY * _imageSize!.height;
              } else {
                continue;
              }
            }

            final scaledX = pixelMinX * _scaleX + _offset.dx;
            final scaledY = pixelMinY * _scaleY + _offset.dy;
            final scaledWidth = (pixelMaxX - pixelMinX) * _scaleX;
            final scaledHeight = (pixelMaxY - pixelMinY) * _scaleY;

            final rect = Rect.fromLTWH(scaledX, scaledY, scaledWidth, scaledHeight);
            boxes.add(rect);
          }
        } catch (e, stackTrace) {
          continue;
        }
      }
    }

    return boxes;
  }

  String _getIngredientLabel(Map<String, dynamic> mapping) {
    final label = mapping['label']?.toString() ?? '';

    if (widget.healthWarnings != null) {
      for (var warning in widget.healthWarnings!) {
        final warningIngredient = warning['ingredient']?.toString().toLowerCase().trim() ?? '';
        if (warningIngredient == label.toLowerCase().trim()) {
          return label;
        }
      }
    }

    return label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Xem thành phần trên ảnh',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                if (_imageSize != null) {
                  _calculateScale(constraints.biggest);
                }

                return Stack(
                  children: [
                    if (_image != null)
                      Center(
                        child: CustomPaint(
                          size: constraints.biggest,
                          painter: ImagePainter(
                            image: _image!,
                            scaleX: _scaleX,
                            scaleY: _scaleY,
                            offset: _offset,
                          ),
                        ),
                      ),
                    if (_displaySize != null && _image != null)
                      CustomPaint(
                        size: constraints.biggest,
                        painter: BoundingBoxPainter(
                          boxes: _getScaledBoundingBoxes(),
                          mappings: widget.mappings,
                          getLabel: _getIngredientLabel,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;
  final double scaleX;
  final double scaleY;
  final Offset offset;

  ImagePainter({
    required this.image,
    required this.scaleX,
    required this.scaleY,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      image.width.toDouble() * scaleX,
      image.height.toDouble() * scaleY,
    );

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BoundingBoxPainter extends CustomPainter {
  final List<Rect> boxes;
  final List<Map<String, dynamic>> mappings;
  final String Function(Map<String, dynamic>) getLabel;

  BoundingBoxPainter({
    required this.boxes,
    required this.mappings,
    required this.getLabel,
  });

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return boxes != oldDelegate.boxes || mappings != oldDelegate.mappings;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes.isEmpty || boxes.length != mappings.length) return;

    final boxPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = Colors.red.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.8),
          blurRadius: 4,
          offset: const Offset(1, 1),
        ),
      ],
    );

    for (int i = 0; i < boxes.length; i++) {
      final box = boxes[i];
      final mapping = mappings[i];

      canvas.drawRect(box, fillPaint);

      canvas.drawRect(box, boxPaint);

      final label = getLabel(mapping);
      if (label.isNotEmpty) {
        final textSpan = TextSpan(text: label, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        );
        textPainter.layout();

        double labelX = box.left;
        double labelY = box.top - textPainter.height - 4;

        if (labelY < 0) {
          labelY = box.top + 4;
        }

        if (labelX + textPainter.width > size.width) {
          labelX = size.width - textPainter.width - 4;
        }

        final bgRect = Rect.fromLTWH(
          labelX - 4,
          labelY - 2,
          textPainter.width + 8,
          textPainter.height + 4,
        );
        final bgPaint = Paint()
          ..color = Colors.red.withOpacity(0.9)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
          bgPaint,
        );

        textPainter.paint(canvas, Offset(labelX, labelY));
      }
    }
  }
}
