import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:tflite/tflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digit Recognizer',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.orange[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.red,
        ),
      ),
      home: DigitRecognizer(),
    );
  }
}

class DigitRecognizer extends StatefulWidget {
  @override
  _DigitRecognizerState createState() => _DigitRecognizerState();
}

class _DigitRecognizerState extends State<DigitRecognizer> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 12,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String _prediction = "";

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    String? result = await Tflite.loadModel(
      model: "assets/models/mnist.tflite",
      labels: "",
    );
    print("Model loaded: $result");
  }

  Future<void> predict() async {
    if (_controller.isEmpty) return;

    final image = await _controller.toImage();
    if (image == null) {
      print("No drawing found.");
      return;
    }
    final resized = await _resizeImage(image, 28, 28);
    final byteData = await resized.toByteData(format: ui.ImageByteFormat.rawRgba);

    var input = _imageToFloatList(byteData!);

    var result = await Tflite.runModelOnBinary(
      binary: input,
      numResults: 1,
      threshold: 0.1,
    );

    setState(() {
      _prediction = result != null && result.isNotEmpty
          ? result[0]['label'].toString()
          : "Couldn't predict";
    });
  }

  Uint8List _imageToFloatList(ByteData byteData) {
    Uint8List buffer = byteData.buffer.asUint8List();
    List<double> imageAsFloat = buffer.map((e) => e / 255.0).toList();

    return Uint8List.fromList(imageAsFloat.map((e) => (e * 255).toInt()).toList());
  }

  Future<ui.Image> _resizeImage(ui.Image image, int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      paint,
    );
    return await recorder.endRecording().toImage(width, height);
  }

  void clearPad() {
    _controller.clear();
    setState(() {
      _prediction = "";
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Digit Recognizer")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Draw a number (0-9):", style: TextStyle(fontSize: 20)),
            SizedBox(height: 10),
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                color: Colors.white,
              ),
              child: Signature(controller: _controller),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: predict,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text("Guess"),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: clearPad,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: Text("Clear"),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text(
              _prediction.isNotEmpty ? "Prediction: $_prediction" : "",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
