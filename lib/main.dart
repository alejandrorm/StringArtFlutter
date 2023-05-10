import 'dart:ui';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';
import 'package:string_art/stage.dart';

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

  MyPainter(this._stage);

  @override
  void paint(Canvas canvas, Size size) {
    if (_stage.isDirty || _picture == null) {
      PictureRecorder recorder = PictureRecorder();
      Canvas recordingCanvas = Canvas(recorder);

      _stage.render(recordingCanvas);
      _picture = recorder.endRecording();
    }

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

  Offset _dragStart = Offset.zero;
  Hit? connectStart;
  Color _lineColor = Colors.black;
  String _spacing = "25";

  void _makeLine(Offset start, Offset end) {
    setState(() {
      String label = 'line ${_lineCount++}';
      _stage.addLine(label, start, end);
    });
  }

  void _pointerDown(PointerDownEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position);

    if (_actionSelections[0]) { // line
      _dragStart = position;
    } else if (_actionSelections[2]) { // connect
      Hit? hit = _stage.hitTest(position);
      if (hit != null) {
        setState(() {
          connectStart = hit;
          _dragStart = hit.offset;
        });
      }
    } else if (_actionSelections[3]) { // select
      setState(() {
        _stage.hitTest(position);
      });
    } else if (_actionSelections[4]) { // delete
      Hit? hit = _stage.hitTest(position);
      if (hit != null) {
        setState(() {
          _stage.removeShape(hit.shape);
        });
      }
    }
  }

  void _pointerUp(PointerUpEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position);

    if (_actionSelections[0]) { // line
      _makeLine(_dragStart, position);
    } else if (_actionSelections[2]) { // connect
      Hit? hit = _stage.hitTest(position);
      if (hit != null && connectStart != null) {
        setState(() {
          _stage.addConnection(connectStart!, hit);
        });
      } else {
        connectStart = null;
      }
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    final renderBox = _painter.currentContext!.findRenderObject() as RenderBox;
    Offset position = renderBox.globalToLocal(event.position);

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

  Widget createConnectionListview() {
    return ListView.builder(
      itemCount: _stage.connections.length,
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
                      onColorChanged: (Color color) => { setState(() => _lineColor = color) },
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
                        setState(() => connection.color = _lineColor);
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
    return ListView.builder(
      itemCount: _stage.shapes.length,
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
                              onChanged: (value) { setState(() => _spacing = value); print(_spacing); },
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
                          double? newSpacing = double.tryParse(_spacing);
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
        actions: <Widget>[
          IconButton(
            icon: const Text('New'),
            tooltip: 'Open file',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This is a snackbar for open')));
            },
          ),
          IconButton(
            icon: const Text('Open'),
            tooltip: 'Save file',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This is a snackbar for save')));
            },
          ),
          IconButton(
            icon: const Text('Save'),
            tooltip: 'Settings',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This is a snackbar for line')));
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
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
                        height: 200,
                        child: createShapeListview(),
                      ),
                    ),
                  ],
                ),
                FittedBox(
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
                          painter: MyPainter(_stage),
                        ),
                      )
                    ),
                  ),
                ),
                Column(
                  children: <Widget>[
                    Text('Connections'),
                    SingleChildScrollView(
                      child: SizedBox(
                        width: 200,
                        height: 200,
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
    );
  }
}
