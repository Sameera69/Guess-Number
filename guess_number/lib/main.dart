import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNIST Digit Recognizer',
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.red)
            .copyWith(secondary: Colors.orange),
      ),
      home: const DigitRecognizer(),
    );
  }
}

class DigitRecognizer extends StatefulWidget {
  const DigitRecognizer({super.key});

  @override
  State<DigitRecognizer> createState() => _DigitRecognizerState();
}

class _DigitRecognizerState extends State<DigitRecognizer> {
  final _points = <Offset>[];

  // Track drawing points on the whiteboard
  void _onPanUpdate(DragUpdateDetails details) {
    RenderBox box = context.findRenderObject() as RenderBox;
    Offset point = box.globalToLocal(details.globalPosition);
    setState(() {
      _points.add(point);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _points.add(Offset.infinite); // sentinel to break lines
    });
  }

  // Clear the drawing
  void _clear() {
    setState(() {
      _points.clear();
    });
  }

  // Convert the current drawing into a 28x28 grayscale list
  Future<List<double>> _convertToImageArray() async {
    // 1. Create a PictureRecorder to draw the points
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 280, 280));

    // White background
    final paintBg = Paint()..color = Colors.white;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 280, 280), paintBg);

    // Draw the user strokes scaled up by 10 (since input will be 280x280)
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 20.0;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != Offset.infinite && _points[i + 1] != Offset.infinite) {
        canvas.drawLine(_points[i] * 10, _points[i + 1] * 10, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(280, 280);
    final byteData =
        await img.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) return List.filled(784, 0.0);

    // 2. Downscale 280x280 to 28x28 grayscale by averaging blocks of 10x10 pixels
    Uint8List pixels = byteData.buffer.asUint8List();

    List<double> grayscale = List.filled(784, 0.0);

    for (int y = 0; y < 28; y++) {
      for (int x = 0; x < 28; x++) {
        double sum = 0;
        for (int dy = 0; dy < 10; dy++) {
          for (int dx = 0; dx < 10; dx++) {
            int px = (y * 10 + dy) * 280 + (x * 10 + dx);
            int index = px * 4;

            int r = pixels[index];
            int g = pixels[index + 1];
            int b = pixels[index + 2];
            // RGBA, ignore A channel

            // Convert to grayscale (simple average)
            double gray = (r + g + b) / 3;
            sum += gray;
          }
        }
        double avgGray = sum / 100;
        // Normalize: 0=white, 1=black (invert)
        grayscale[y * 28 + x] = (255 - avgGray) / 255;
      }
    }

    return grayscale;
  }

  Future<void> _onGuess() async {
    if (_points.isEmpty) {
      _showDialog('Draw a digit first!');
      return;
    }

    List<double> imageArray = await _convertToImageArray();

    // Call JS function
    final prediction =
        await js.context.callMethod('predictDigit', [imageArray]);

    _showDialog('Prediction: $prediction');
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Result'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MNIST Digit Recognizer'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _DrawingPainter(_points),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: _clear,
                  child: const Text('Clear', style: TextStyle(color: Colors.white)),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _onGuess,
                  child: const Text('Guess', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<Offset> points;

  _DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 20.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter oldDelegate) =>
      oldDelegate.points != points;
}
