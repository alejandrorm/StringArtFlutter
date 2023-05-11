import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';
import 'package:string_art/stage.dart';

// TODO:
// 1: Options for connections
//   a: Wrap around
//   b: Skip ticks
// 2: Implement circles
// 3: Export
// 4: Save
// 5: Load
// 6: Undo/Redo
// ---- 7: Zoom
// ---- 8: Pan
// ---- 9: Background color
// 10: status bar with size and location

void main() {
  runApp(const MyApp());
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
      home: const MyHomePage(title: 'String Art Editor'),
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

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey _painter = GlobalKey();
  final List<bool> _actionSelections = List.generate(5, (_) => false);
  final List<bool> _displaySelections = <bool>[false, true];
  final Stage _stage = Stage();
  int _lineCount = 0;

  double _zoom = 1.0;
  Offset _offset = Offset.zero;

  Offset _dragStart = Offset.zero;
  Hit? connectStart;
  Color _holdingColor = Colors.black;
  String _holdingSpacing = "25";

  void _makeLine(Offset start, Offset end) {
    setState(() {
      String label = 'line ${_lineCount++}';
      _stage.addLine(label, start, end);
    });
  }

  void _pointerDown(PointerDownEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    if (_actionSelections[0]) { // line
      _dragStart = position;
    } else if (_actionSelections[2]) { // connect
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
    } else if (_actionSelections[3]) { // select
      setState(() {
        _stage.hitTest(position, 5 / _zoom);
      });
    } else if (_actionSelections[4]) { // delete
      Hit? hit = _stage.hitTest(position, 5 / _zoom);
      if (hit != null) {
        setState(() {
          _stage.removeShape(hit.shape);
        });
      }
    }
  }

  void _pointerUp(PointerUpEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    if (_actionSelections[0]) { // line
      _makeLine(_dragStart, position);
    } else if (_actionSelections[2]) { // connect
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
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position) - _stage.offset;
    position /= _zoom;

    if (_actionSelections.every((element) => !element)) {
      setState(() {
        _stage.offset += event.delta;
      });
    }
    if (_actionSelections[0] || _actionSelections[2]) {
      setState(() {
        _stage.setTempLine(_dragStart, position);
      });
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
            icon: const Icon(Icons.circle),
            color: connection.color,
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) { return AlertDialog(
                  title: const Text('Pick a color'),
                  content: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: connection.color,
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
                        setState(() => connection.color = _holdingColor);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );},
              );
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
            icon: const Icon(Icons.edit),
            onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) { return AlertDialog(
                    title: Text('\'${shape.label}\' properties'),
                    content: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text('Spacing: '),
                          SizedBox(
                            width: 100,
                            child:
                            TextField(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(text: shape.spacing.toString()),
                              onChanged: (value) { setState(() => _holdingSpacing = value); print(_holdingSpacing); },
                            )
                          ),
                        ],
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
                          double? newSpacing = double.tryParse(_holdingSpacing);
                          if (newSpacing != null) {
                            setState(() => shape.spacing = newSpacing);
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid number'),
                                  duration: Duration(seconds: 3),
                                )
                            );
                          }
                        },
                      ),
                    ],
                  );},
                );
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
                    onPressed: _undo,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                      onPressed: _redo,
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
                _stage.controlPoints = _actionSelections[2] || _actionSelections[3] || _actionSelections[4];
              });
            },
            children: const <Widget>[
              Text('Line'),
              Text('Circle'),
              Text('Connect'),
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
                    Text('Shapes'),
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
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Load'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('Save as...'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Export PNG...'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      )
    );
  }
}
