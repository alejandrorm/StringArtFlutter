import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';
import 'package:string_art/stage.dart';
import 'package:string_art/custom_icons_icons.dart';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';

import 'package:universal_html/html.dart' as html;

// TODO:
// 1: Options for connections
//   a: Wrap around
//    Export template
// 4: Save
// 5: Load
// 6: Undo/Redo

void main() {
  runApp(const MyApp());
}


// keep in sync with action bar
enum Action {
  line,
  circle,
  connect,
  move,
  delete,
  none
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'String Art Editor',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'String Art Editor'),
    );
  }
}

class MyPainter extends CustomPainter {

  final Stage _stage;
  Picture? _picture;
  final double _zoom;

  MyPainter(this._stage, this._zoom);

  @override
  void paint(Canvas canvas, Size size) {
    if (_stage.isDirty || _picture == null) {
      PictureRecorder recorder = PictureRecorder();
      Canvas recordingCanvas = Canvas(recorder);

      _stage.render(recordingCanvas);
      _picture = recorder.endRecording();
    }

    canvas.translate(_stage.offset.dx, _stage.offset.dy);
    canvas.scale(_zoom);
    canvas.drawPicture(_picture!);
    _stage.renderTemp(canvas);
  }

  @override
  bool shouldRepaint(MyPainter oldDelegate) {
    return true;
  }
  
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  // final CounterStorage storage;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey _painter = GlobalKey();
  String adjustedSpacingText = "10";
  final List<bool> _actionSelections = List.generate(5, (_) => false);
  final List<bool> _displaySelections = <bool>[false, true];
  final Stage _stage = Stage();
  Action _action = Action.none;
  int _lineCount = 0;

  double _zoom = 1.0;
  Offset _offset = Offset.zero;
  int _currentX = 0;
  int _currentY = 0;

  Offset _dragStart = Offset.zero;
  Hit? connectStart;
  Color _holdingColor = Colors.black;
  double _holdingSpacing = 0;
  int _startStep = 1;
  int _startSkip = 1;
  int _endStep = 1;
  int _endSkip = 1;

  Future<ByteData?> _getImageData() async {
    PictureRecorder recorder = PictureRecorder();
    Canvas recordingCanvas = Canvas(recorder);
    Rectangle bounds = _stage.boundingBox;
    recordingCanvas.translate(-bounds.left.toDouble() + 25, -bounds.top.toDouble() + 25);
    _stage.render(recordingCanvas);
    Picture picture = recorder.endRecording();
    var image = await picture.toImage(_stage.size.width.toInt() + 50,
        _stage.size.height.toInt() + 50);

    return image.toByteData(format: ImageByteFormat.png);
  }

  Future<void> _saveFile() async {
    if (kIsWeb) {
      ByteData? byteData = await _getImageData();
      final buffer = byteData!.buffer;
      final blob = html.Blob([buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement()
        ..href = url
        ..download = 'string-art.png'
        ..type = 'image/png'
        ..style.display = 'none'
        ..click();
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: 'string-art.png',
        // type: FileType.image,
        allowedExtensions: ['png'],
      );

      if (outputFile != null) {
        ByteData? byteData = await _getImageData();

        final buffer = byteData!.buffer;
        File(outputFile).writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
    } else {
      String? outputFile = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Please select an output folder:',
      );

      if (outputFile != null) {
        ByteData? byteData = await _getImageData();

        final buffer = byteData!.buffer;
        File('$outputFile\\string-art.png').writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      }
    }
  }

  void _makeLine(Offset start, Offset end) {
    setState(() {
      String label = 'line ${_lineCount++}';
      double spacing = _getAdjustedSpacing((start - end).distance, 25.0);
      _stage.addLine(label, start, end, spacing);
    });
  }

  void _makeCircle(Offset center, double radius) {
    setState(() {
      String label = 'circle ${_lineCount++}';
      double spacing = _getAdjustedSpacing(radius.toInt() * 2 * pi, 25);
      _stage.addCircle(label, center, radius.toInt(), spacing);
    });
  }

  void _pointerDown(PointerDownEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    switch (_action) {
      case Action.line:
        _dragStart = position;
        break;
      case Action.circle:
        _dragStart = position;
        break;
      case Action.connect:
        Hit? hit = _stage.hitTest(position, 5 / _zoom);
        if (hit != null) {
          setState(() {
            connectStart = hit;
            _dragStart = hit.offset;
          });
        } else {
          setState(() {
            _stage.cancelPartialLine();
            connectStart = null;
          });
        }
        break;
      case Action.move:
        Hit? hit = _stage.hitTest(position, 5 / _zoom);
        // if (hit != null) {
        //   setState(() {
        //     _stage.startMove(hit);
        //   });
        // }
        break;
      case Action.delete:
        Hit? hit = _stage.hitTest(position, 5 / _zoom);
        if (hit != null) {
          setState(() {
            _stage.removeShape(hit.shape);
          });
        }
        break;
      case Action.none:
        break;
    }
  }

  void _pointerUp(PointerUpEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    switch(_action) {
      case Action.line:
        _makeLine(_dragStart, position);
        break;
      case Action.circle:
        _makeCircle(_dragStart, (position - _dragStart).distance);
        break;
      case Action.connect:
        Hit? hit = _stage.hitTest(position, 5 / _zoom);
        if (hit != null && connectStart != null) {
          setState(() {
            _stage.addConnection(connectStart!, hit);
          });
        } else {
          setState(() {
            _stage.cancelPartialLine();
            connectStart = null;
          });
        }
        break;
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    switch(_action) {
      case Action.none:
        setState(() {
          _stage.offset += event.delta;
        });
        break;
      case Action.line:
        Hit? hit = _stage.hitTest(position, 5 / _zoom);
        setState(() {
          (hit != null && _actionSelections[0]) ? _stage.setHover(hit) : _stage.clearHover();
          _stage.setTempLine(_dragStart, position);
        });
        break;
      case Action.circle:
        setState(() {
          _stage.setTempCircle(_dragStart, (position - _dragStart).distance.toInt());
        });
        break;
      case Action.connect:
        Hit? hit = _stage.hitTest(position, 5 / _zoom);
        setState(() {
          (hit != null) ? _stage.setHover(hit) : _stage
              .clearHover();
          _stage.setTempLine(_dragStart, position);
        });
        break;
      default:
        break;
    }
  }

  void _pointerHover(PointerHoverEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    if (_action != Action.none) {
      setState(() {
        _currentX = position.dx.toInt();
        _currentY = position.dy.toInt();
      });
    }

    if (_action == Action.connect || _action == Action.move ||
        _action == Action.delete) {
      Hit? hit = _stage.hitTest(position, 5 / _zoom);
      if (hit != _stage.hit) {
        setState(() {
          (hit != null) ? _stage.setHover(hit) : _stage.clearHover();
        });
      }
    }
  }

  void _undo() {

  }

  void _redo() {

  }

  void _zoomIn() {
    setState(() {
      _zoom *= 1.1;
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom /= 1.1;
    });
  }

  double _getAdjustedSpacing(double length, double spacing) {
    if (spacing > length) spacing = length;

    int steps = (length / spacing).floor();
    double adjustedSpacing = length / steps;
    return adjustedSpacing;
  }

  double _getAdjustedSpacingForShape(Shape shape, double spacing) {
    double length = 0;
    if (shape is Circle) length = 2 * pi * shape.radius;
    if (shape is Line) length = (shape.end - shape.start).distance;

    return _getAdjustedSpacing(length, spacing);
  }

  // double _getAdjustedSpacingForSteps(Shape shape , int steps) {
  //   double length = 0;
  //   if (shape is Circle) length = 2 * pi * shape.radius;
  //   if (shape is Line) length = (shape.end - shape.start).distance;
  //
  //   double lb = 0;
  //   double ub = length;
  //   double spacing = (ub + lb) / 2;
  //   int stepsTarget = steps * 1000;
  //   int currentSteps = ((length / spacing) * 1000).round();
  //
  //   while (currentSteps != stepsTarget) {
  //     if (currentSteps > stepsTarget) {
  //       lb = spacing;
  //     } else {
  //       ub = spacing;
  //     }
  //     spacing = (ub + lb) / 2;
  //     currentSteps = ((length / spacing) * 1000).round();
  //   }
  //
  //   return spacing;
  // }

  int _getSteps(Shape shape) {
    double length = 0;
    if (shape is Circle) length = 2 * pi * shape.radius;
    if (shape is Line) length = (shape.end - shape.start).distance;

    int steps = (length / shape.spacing).round();
    return steps;
  }

  void showShapeEditDialog(Shape shape) {
    _holdingSpacing = shape.spacing;
    adjustedSpacingText = _holdingSpacing.toStringAsFixed(3);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit shape \'${shape.label}\''),
          content: Column(
            children: [
              Row(

                children: [
                  Text('Length: '),
                  Text(
                      shape is Line? (shape.end - shape.start).distance.toStringAsFixed(1) : (2 * pi * (shape as Circle).radius).toStringAsFixed(1)
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Spacing: '),
                  SizedBox(width: 100, height: 30,
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                          text: shape.spacing.toStringAsFixed(3)),
                      onChanged: (text) {
                        var space = double.tryParse(text);
                        if (space != null && space > 0) {
                          setState(() {
                            shape.spacing = _getAdjustedSpacingForShape(shape, space);
                            adjustedSpacingText =
                                shape.spacing.toStringAsFixed(3);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              // Row(
              //   children: [
              //     Text('Adjusted spacing: '),
              //     Text(adjustedSpacingText),
              //   ],
              // ),
              Row(
                children: [
                  Text('Steps: '),
                  SizedBox(width: 100, height: 30,
                    child: TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                          text: _getSteps(shape).toString()),
                      onChanged: (text) {
                        var steps = int.tryParse(text);
                        if (steps != null && steps > 0) {
                          setState(() {
                            if (shape is Line) {
                              shape.spacing = (shape.end - shape.start).distance / steps;
                            } else if (shape is Circle) {
                              shape.spacing = (2 * pi * shape.radius) / steps;
                            }
                            // shape.spacing = _getAdjustedSpacingForSteps(shape, steps);
                            adjustedSpacingText = shape.spacing.toStringAsFixed(3);
                          });
                        }
                      },
                    ),
                  ), //Text(_getSteps(shape).toString()),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                setState(() {
                  shape.spacing = _holdingSpacing;
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                // double? newSpacing = double.tryParse(_holdingSpacing);
                // if (newSpacing != null) {
                //   setState(() => shape.spacing = _getAdjustedSpacingForShape(shape));
                //   Navigator.of(context).pop();
                // } else {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text('Please enter a valid spacing value'),
                //         duration: Duration(seconds: 3),
                //       )
                //   );
                // }
              },
            ),
          ],
        );
      },
    );
  }

  void showConnectionEditDialog(Connection connection) {
    _holdingColor = connection.color;
    _endSkip = connection.endSkipEvery;
    _endStep = connection.endSkipBy;
    _startSkip = connection.startSkipEvery;
    _startStep = connection.startSkipBy;

    showDialog(
      context: context,
      builder: (BuildContext context) { return AlertDialog(
        title: const Text('Edit connection'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              const Text('Color'),
              ColorPicker(
                pickerColor: connection.color,
                onColorChanged: (color) {
                  setState(() {
                    _holdingColor = color;
                  });
                },
                pickerAreaHeightPercent: 0.8,
              ),
              const Text('Source'),
              Row(
                children: [
                  Text('Skip by: '),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: TextEditingController(text: connection.startSkipBy.toString()),
                      onChanged: (text) {
                        setState(() {
                          _startStep = int.tryParse(text) ?? connection.startSkipBy;
                        });
                      },
                    ),
                  ),
                  Text(' every: '),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: TextEditingController(text: connection.startSkipEvery.toString()),
                      onChanged: (text) {
                        setState(() {
                          _startSkip = int.tryParse(text) ?? connection.startSkipEvery;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const Text('Destination'),
              Row(
                children: [
                  Text('Skip by: '),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: TextEditingController(text: connection.endSkipBy.toString()),
                      onChanged: (text) {
                        setState(() {
                          _endStep = int.tryParse(text) ?? connection.endSkipBy;
                        });
                      },
                    ),
                  ),
                  Text(' every: '),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: TextEditingController(text: connection.endSkipEvery.toString()),
                      onChanged: (text) {
                        setState(() {
                          _endSkip = int.tryParse(text) ?? connection.endSkipEvery;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              setState(() {
                connection.color = _holdingColor;
                connection.startSkipBy = _startStep;
                connection.endSkipBy = _endStep;
                connection.endSkipEvery = _endSkip;
                connection.startSkipEvery = _startSkip;
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ); }
    );
  }

  Widget createConnectionListview() {
    return ListView.separated(
      itemCount: _stage.connections.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        Connection connection = _stage.connections[index];
        return ListTile(
          title: Text('${connection.start.shape.label} -> ${connection.end.shape.label}'),
          selected: connection.selected,
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                _stage.removeConnection(connection);
              });
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showConnectionEditDialog(connection);
            },
          ),
          onTap: () {
            setState(() {
              bool selected = connection.selected;
              for (Connection connection in _stage.connections) {
                connection.selected = false;
              }
              connection.selected = !selected;
            });
          },
        );
      },
    );
  }

  Widget createShapeListview() {
    return ListView.separated(
      itemCount: _stage.shapes.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        Shape shape = _stage.shapes[index];
        return ListTile(
          title: Text(shape.label),
          selected: shape.selected,
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                _stage.removeShape(shape);
              });
            },
          ),
          leading: IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showShapeEditDialog(shape);
            },
          ),
          onTap: () {
            setState(() {
              bool selected = shape.selected;
              for (Shape shape in _stage.shapes) {
                shape.selected = false;
              }
              shape.selected = !selected;
            });
          },
        );
      },
    );
  }

  Widget createActionBar() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Material(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Wrap(
                children: <Widget>[
                  IconButton(
                    onPressed: null, //_undo,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                      onPressed:  null, //_redo,
                      icon: const Icon(Icons.redo)
                  ),
                ],
              )
          ),
          const SizedBox(
            width: 20,
          ),
          ToggleButtons(
            isSelected: _actionSelections,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onPressed: (int index) {
              setState(() {
                for (int buttonIndex = 0; buttonIndex < _actionSelections.length; buttonIndex++) {
                  if (buttonIndex != index) {
                    _actionSelections[buttonIndex] = false;
                  }
                }
                _actionSelections[index] = !_actionSelections[index];
                if (_actionSelections[index]) {
                  _action = Action.values[index];
                } else {
                  _action = Action.none;
                }
                _stage.controlPoints = _actionSelections[3] || _actionSelections[4];
              });
            },
            children: const <Widget>[
              Icon(CustomIcons.flow_line),
              Icon(CustomIcons.circle_thin),
              Icon(CustomIcons.connectdevelop),
              Text('Move'),
              Text('Delete'),
            ],
          ),
          const SizedBox(
            width: 20,
          ),
          Material(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Wrap(
                children: <Widget>[
                  IconButton(
                    onPressed: _zoomIn,
                    icon: const Icon(Icons.zoom_in),
                  ),
                  IconButton(
                      onPressed: _zoomOut,
                      icon: const Icon(Icons.zoom_out)
                  ),
                ],
              )
          ),
          OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) { return AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: _stage.backgroundColor,
                        onColorChanged: (Color color) => { setState(() => _holdingColor = color) },
                      ),
                    ),
                    actions: <Widget>[
                      ElevatedButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      ElevatedButton(
                        child: const Text('Accept'),
                        onPressed: () {
                          setState(() => _stage.backgroundColor = _holdingColor);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );},
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.transparent,
                ),
              ),
              child: SizedBox(
                width: 30,
                height: 30,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: _stage.backgroundColor,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(color: Colors.black),
                  ),
                ),
              )
          ),
          const SizedBox(
            width: 20,
          ),
          ToggleButtons(
            isSelected: _displaySelections,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            onPressed: (int index) {
              setState(() {
                _displaySelections[index] = !_displaySelections[index];
                if (index == 0) {
                  _stage.showLabels = _displaySelections[index];
                } else {
                  _stage.showConnections = _displaySelections[index];
                }
              });
            },
            children: const <Widget>[
              Text('Labels'),
              Text('Connections'),
            ],
          ),
        ]
    );
  }

  String truncateZoom(double zoom) {
    if (zoom > 1000) {
      return (zoom ~/ 100 * 100).toString();
    } else if (zoom > 100) {
      return (zoom ~/ 10 * 10).toString();
    } else if (zoom > 40) {
      return (zoom ~/ 5 * 5).toString();
    } else if (zoom > 0.5) {
      return zoom.toStringAsFixed(1);
    } else if (zoom > 0.1) {
      return zoom.toStringAsFixed(2);
    } else {
      return "< 0.1";
    }
  }

  Widget getCurrentConstruction() {
    if (_action == Action.line && _stage.partialLine != null) {
      return Text('Line from ${_stage.partialLine!.start.dx.toStringAsFixed(1)}, '
          '${_stage.partialLine!.start.dy.toStringAsFixed(1)} to '
          '${_stage.partialLine!.end.dx.toStringAsFixed(1)}, '
          '${_stage.partialLine!.end.dy.toStringAsFixed(1)} '
          '(length ${_stage.partialLine!.length().toStringAsFixed(1)})');
    }
    if (_action == Action.circle && _stage.partialCircle != null) {
      return Text('Circle at ${_stage.partialCircle!.center.dx.toStringAsFixed(1)}, '
          '${_stage.partialCircle!.center.dy.toStringAsFixed(1)} with radius '
          '${_stage.partialCircle!.radius.toStringAsFixed(1)}');
    }
    return const SizedBox(width: 300);
  }

  Widget createBottomBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Text('Canvas Size: ${_stage.size.width.toStringAsFixed(1)} x ${_stage.size.height.toStringAsFixed(1)}'),
          Text('Cursor at ($_currentX, $_currentY)'),
          getCurrentConstruction(),
          Text('Zoom: ${truncateZoom(_zoom * 100)}%'),
        ],
      )
    );
  }

  MouseCursor _getCursor() {
    if (_actionSelections.every((element) => !element)) {
     return SystemMouseCursors.move;
    } else {
      return SystemMouseCursors.precise;
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            createActionBar(),
            Row(
              children: const [
                SizedBox(
                  height: 20,
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const Text('Shapes'),
                    SingleChildScrollView(
                      child: SizedBox(
                        width: 200,
                        height: 500,
                        child: createShapeListview(),
                      ),
                    ),
                  ],
                ),
                MouseRegion(
                  cursor: _getCursor(),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: SizedBox(
                      width: 500,
                      height: 500,
                      child: Listener(
                        onPointerDown: _pointerDown,
                        onPointerUp: _pointerUp,
                        onPointerMove: _pointerMove,
                        onPointerHover: _pointerHover,
                        child: ClipRect(
                          child: CustomPaint(
                            key: _painter,
                            painter: MyPainter(_stage, _zoom),
                          ),
                        )
                      ),
                    ),
                  ),
                ),
                Column(
                  children: <Widget>[
                    Text('Connections'),
                    SingleChildScrollView(
                      child: SizedBox(
                        width: 200,
                        height: 500,
                        child: createConnectionListview(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            // ListTile(
            //   leading: const Icon(Icons.add),
            //   title: const Text('New'),
            //   onTap: () {
            //     Navigator.pop(context);
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.open_in_browser),
            //   title: const Text('Load'),
            //   onTap: () {
            //     Navigator.pop(context);
            //   },
            // ),
            // ListTile(
            //   leading: const Icon(Icons.save),
            //   title: const Text('Save as...'),
            //   onTap: () {
            //     Navigator.pop(context);
            //   },
            // ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Export PNG...'),
              onTap: () {
                _saveFile();
                Navigator.pop(context);
              },
            ),
            // ListTile(
            //   title: const Text('About'),
            //   onTap: () {
            //     Navigator.pop(context);
            //   },
            // ),
          ],
        ),
      ),
      bottomNavigationBar: createBottomBar(),
    );
  }
}
