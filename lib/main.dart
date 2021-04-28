import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_better_camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as sravanImage;

import 'package:strip_detection/detector_painters.dart';
import 'package:strip_detection/scanner_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strip Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StripCameraDectection(),
    );
  }
}

class StripCameraDectection extends StatefulWidget {
  @override
  _StripCameraDectectionState createState() => _StripCameraDectectionState();
}

class _StripCameraDectectionState extends State<StripCameraDectection> {
  dynamic _scanResults;
  CameraController _camera;
  Detector _currentDetector = Detector.face;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.front;
  String _path;

  final FaceDetector _faceDetector = FirebaseVision.instance.faceDetector();

  @override
  void initState() {
    super.initState();
    initializeFlutterFire();
    _initializeCamera();
  }

  initializeFlutterFire() async {
    await Firebase.initializeApp()
        .whenComplete(() => print("Firebase Initialised"));
  }

  Future<void> _initializeCamera() async {
    final CameraDescription description =
        await ScannerUtils.getCamera(_direction);

    _camera = CameraController(
      description,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
    );
    await _camera.initialize();

    await _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      ScannerUtils.detect(
        image: image,
        detectInImage: _faceDetector.processImage,
        imageRotation: description.sensorOrientation,
      ).then(
        (dynamic results) {
          if (!mounted) return;
          setState(() {
            _scanResults = results;
          });
        },
      ).whenComplete(() => _isDetecting = false);
    });
  }

  Widget _buildResults() {
    const Text noResultsText = Text('No results!');

    if (_scanResults == null ||
        _camera == null ||
        !_camera.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;
    final Size imageSize = Size(
      _camera.value.previewSize.height,
      _camera.value.previewSize.width,
    );

    if (_scanResults is! List<Face>) return noResultsText;
    painter = FaceDetectorPainter(imageSize, _scanResults);

    return CustomPaint(
      painter: painter,
    );
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _camera == null
          ? const Center(
              child: Text(
                'Initializing Camera...',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 30,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              // crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                CameraPreview(_camera),
                _buildResults(),
              ],
            ),
    );
  }

  _capture() async {
    print("Capture Called");
    await _camera.stopImageStream();

    Directory d = await getExternalStorageDirectory();
    DateTime date = DateTime.now();
    setState(() {
      _path = "${d.path}/Image_${date.toIso8601String()}.jpeg";
    });
    // final finalImage = await new File(path).create();
    // final result = await img.readAsBytes();
    // finalImage.writeAsBytesSync(result);
    await _camera.takePicture(_path);
    print("Image Captured");
    // print("Editing Image");
    // await _editImage();
  }

  _editImage() async {
    final Face face = await _scanResults[0];
    final left = face.boundingBox.left.truncate();
    final right = face.boundingBox.right.truncate();
    final top = face.boundingBox.top.truncate();
    final bottom = face.boundingBox.bottom.truncate();

    print("Sravan " + face.boundingBox.toString());

    Directory d = await getExternalStorageDirectory();
    DateTime date = DateTime.now();

    File img = File(_path);
    sravanImage.Image originalImage =
        sravanImage.decodeImage(img.readAsBytesSync());
    sravanImage.Image faceCrop =
        sravanImage.copyCrop(originalImage, left, top, right, bottom);
    final encodedImg = sravanImage.encodeJpg(faceCrop);

    final decodedImg = await decodeImageFromList(encodedImg);
    // final result = faceCrop.getBytes(format: sravanImage.Format.argb);
    final result = await decodedImg.toByteData();

    final finalPath = "${d.path}/Face_Image_${date.toIso8601String()}.png";
    final finalImage = await new File(finalPath).create();
    final finalResult =
        result.buffer.asUint8List(result.offsetInBytes, result.lengthInBytes);
    finalImage.writeAsBytesSync(finalResult);
    // sravanImage.encodePng(finalImage);
    print("Face crop finished");

    // final byteData = faceCrop.getBytes(format: sravanImage.Format.argb);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Strip Detection"),
      ),
      body: _buildImage(),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt_outlined),
        onPressed: _capture,
      ),
    );
  }

  @override
  void dispose() {
    _camera.dispose().then((_) {
      _faceDetector.close();
    });

    super.dispose();
  }
}
