import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewPage extends StatefulWidget {

  const CameraPreviewPage({
    super.key,
    required this.camera
  });

  final CameraDescription camera;

  @override
  CameraPreviewPageState createState() => CameraPreviewPageState();
}

class CameraPreviewPageState extends State<CameraPreviewPage> {

  late CameraController _cameraCtrl;
  late Future<void> _initializeCameraCtrlFuture;

  @override
  void initState() {
    super.initState();

    _cameraCtrl = CameraController(widget.camera, ResolutionPreset.ultraHigh);
    _initializeCameraCtrlFuture = _cameraCtrl.initialize();
  }

  @override
  void dispose() {
    _cameraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        title: const Text('Camera Preview')
      ),
      body: FutureBuilder(
        future: _initializeCameraCtrlFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_cameraCtrl);
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeCameraCtrlFuture;
            final image = await _cameraCtrl.takePicture();
            
            if (!context.mounted) return;
            Navigator.pop(context, image);
          } catch (e) {
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
