import 'dart:collection';

class WordBox {

  String text;
  List<List<num>> vertices;
  late List<List<num>> boundingBox;
  late num lineNum;
  late List match = [];
  late bool matched = false;

  WordBox({
    required this.text,
    required this.vertices
  });

  setBox(List<List<num>> boundingBox) {
    this.boundingBox = boundingBox;
  }
  pushMatch(HashMap<String, int> match) {
    this.match.add(match);
  }
  setlineNum(num lineNum) {
    this.lineNum = lineNum;
  }
  setMatched(bool matched) {
    this.matched = matched;
  }
}
