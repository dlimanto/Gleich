import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gleich/camera-preview.page.dart';
import 'package:gleich/models/word-box.model.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:point_in_polygon/point_in_polygon.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {

  const MyHomePage({
    super.key, 
    required this.title
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  void initState() {
    super.initState();
  }

  Future<void> _takePhoto() async {
    final XFile data = await Navigator.push(context, MaterialPageRoute(builder: (context) => CameraPreviewPage(camera: _cameras[0])));

    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(InputImage.fromFile(File(data.path)));

    _getText(recognizedText);
    textRecognizer.close();
  }

  void _getText(RecognizedText text) {
    List<WordBox> mergedLines = [];

    for (TextBlock block in text.blocks) {
      for (TextLine line in block.lines) {
        List<List<num>> tempVertices = [];
        String words = '';

        for (dynamic p in line.cornerPoints) {
          tempVertices.add([ p.x, p.y ]);
        }
        
        for (TextElement el in line.elements) {
          words = '$words ${ el.text }';
        }
        mergedLines.add(WordBox(text: words, vertices: tempVertices));
      }
    }

    _getBoundingPolygon(mergedLines);
    _combineBoundingPolygon(mergedLines);

    List<String> finalLines = _constructLineWithBoundingPolygon(mergedLines);
    for (String line in finalLines) {
      print(line);
    }
  }

  void _getBoundingPolygon(List<WordBox> mergedLines) {
    for(int i = 0; i < mergedLines.length; i++){
      List<List<num>> points = [];

      num h1 = (mergedLines[i].vertices[0][1] - mergedLines[i].vertices[3][1]).abs();
      num h2 = (mergedLines[i].vertices[1][1] - mergedLines[i].vertices[2][1]).abs();
      
      num h = max(h1, h2);
      num avgHeight = h * 0.6;
      num threshold = h * 1;

      points.add(mergedLines[i].vertices[1]);
      points.add(mergedLines[i].vertices[0]);
      List<num> topLine = _getLineMesh(points, avgHeight, true);

      points = [];

      points.add(mergedLines[i].vertices[2]);
      points.add(mergedLines[i].vertices[3]);
      List<num> bottomLine = _getLineMesh(points, avgHeight, false);

      mergedLines[i].setBox(
        [
          [ topLine[0], topLine[2] - threshold ], 
          [ topLine[1], topLine[3] - threshold ], 
          [ bottomLine[1], bottomLine[3] + threshold ], 
          [ bottomLine[0], bottomLine[2] + threshold ]
        ]
      );
      mergedLines[i].setlineNum(i);
    }
  }

  List<num> _getLineMesh(List p, avgHeight, bool isTopLine) {
    if (isTopLine) {
      p[1][1] += avgHeight;
      p[0][1] += avgHeight;
    } else {
      p[1][1] -= avgHeight;
      p[0][1] -= avgHeight;
    }
    num xDiff = (p[1][0] - p[0][0]);
    num yDiff = (p[1][1] - p[0][1]);
    
    num gradient = yDiff / xDiff;
    num xThreshMin = 1;
    num xThreshMax = 3000;

    num yMin = 0;
    num yMax = 0;

    if (gradient == 0) {
      yMin = p[0][1];
      yMax = p[0][1];
    } else {
      yMin = p[0][1] - (gradient*(p[0][0] - xThreshMin));
      yMax = p[0][1] + (gradient*(p[0][0] + xThreshMax));
    }

    return [ xThreshMin, xThreshMax, yMin, yMax ];
  }

  void _combineBoundingPolygon(List<WordBox> mergedLines) {
    for (int i = 0; i < mergedLines.length; i++) {
      for (int k = i; k < mergedLines.length; k++) {
        if (k != i && mergedLines[k].matched == false) {
          int insideCount = 0;
          
          for (int j = 0; j < 4; j++) {
            List<num> coordinate = mergedLines[k].vertices[j];
            final List<Point> points = [];

            for (List<num> c in mergedLines[i].boundingBox) {
              points.add(
                Point(x: c[0].toDouble(), y: c[1].toDouble())
              );
            }
            
            if (Poly.isPointInPolygon(Point(x: coordinate[0].toDouble(), y: coordinate[1].toDouble()), points)) {
              insideCount++;
            }
          }

          if (insideCount == 4) {
            HashMap<String, int> match = HashMap<String, int>();
            
            match['matchCount'] = insideCount;
            match['matchLineNum'] = k;
            
            mergedLines[i].pushMatch(match);
            mergedLines[k].setMatched(true);
          }
        }
      }
    }
  }

  List<String> _constructLineWithBoundingPolygon(List<WordBox> mergedLines){
    List<String> finalLines = [];

    for (int i = 0; i < mergedLines.length; i++) {
      if (mergedLines[i].matched == false) {
        if (mergedLines[i].match.isEmpty) { 
          finalLines.add(mergedLines[i].text);
          continue;
        }

        finalLines.add(_arrangeWordsInOrder(mergedLines, i));
      }
    }
    return finalLines;
  }

  String _arrangeWordsInOrder(List<WordBox> mergedLines, int i) {
    String mergedLine = '';
    List<dynamic> line = mergedLines[i].match;

    for (int j = 0; j < line.length; j++) {
      int index = line[j]['matchLineNum'];
      String matchedWordForLine = mergedLines[index].text;
      
      num mainX = mergedLines[i].vertices[0][0];
      num compareX = mergedLines[index].vertices[0][0];

      if(compareX > mainX){
        mergedLine = '${ mergedLines[i].text } $matchedWordForLine';
        continue;
      }
      mergedLine = '$matchedWordForLine ${ mergedLines[i].text }';
    }
    return mergedLine;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              'Hello world',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePhoto,
        tooltip: 'Open Camera',
        child: const Icon(Icons.camera_alt_rounded),
      ),
    );
  }
}
