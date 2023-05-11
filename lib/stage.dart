import 'package:flutter/material.dart';

class Stage {
  bool isDirty = true;
  bool _showLabels = false;
  bool _showConnections = true;
  bool _controlPoints = false;
  final Map<String, Shape> _shapes = {};
  final List<Connection> _connections = [];
  Color _backgroundColor = Colors.white;

  int ticks = 25;
  Offset offset = Offset.zero;
  Hit? _hit;
  Line? _partialLine;
  Circle? _partialCircle;

  static const _textStyle = TextStyle(
    color: Colors.black,
    fontSize: 10,
  );

  void cancelPartialLine() {
    _partialLine = null;
  }

  void render(Canvas canvas) {
    canvas.drawColor(_backgroundColor, BlendMode.src);

    for(Shape shape in _shapes.values) {
      shape.render(canvas, _showLabels, _controlPoints);
    }
    if (_showConnections) {
      for (Connection connection in _connections) {
        connection.render(canvas);
      }
    }
    isDirty = false;
  }

  void setTempLine(Offset start, Offset end) {
    _partialLine = Line('temp', start, end);
  }

  void addLine(String label, Offset start, Offset end) {
    _shapes[label] = Line(label, start, end);
    _partialLine = null;
    isDirty = true;
  }

  void addCircle(String label, Offset center, int radius) {
    _shapes[label] = Circle(label, center, radius);
    isDirty = true;
  }

  void removeShape(Shape shape) {
    _shapes.remove(shape.label);
    _connections.removeWhere((connection) => connection.start.shape == shape ||
                                             connection.end.shape == shape);
    isDirty = true;
  }

  void removeConnection(Connection connection) {
    _connections.remove(connection);
    isDirty = true;
  }

  List<Connection> get connections => _connections;

  List<Shape> get shapes => _shapes.values.toList();

  void addConnection(Hit start, Hit end) {
    _connections.add(Connection(start, end));
    isDirty = true;
    _partialLine = null;
  }

  void renderTemp(Canvas canvas) {
    // _hit?.render(canvas);
    _partialLine?.selected = true;
    _partialLine?.render(canvas, false, true);
    _partialCircle?.render(canvas, false, false);
  }

  Hit? hitTest(Offset offset, double tolerance) {
    for (Shape shape in _shapes.values) {
      Hit? hit = shape.hitTest(offset, tolerance);
      if (hit != null) {
        _hit = hit;
        return _hit;
      }
    }
    _hit = null;
    return null;
  }

  set showLabels(bool value) {
    _showLabels = value;
    isDirty = true;
  }

  set showConnections(bool value) {
    _showConnections = value;
    isDirty = true;
  }

  set controlPoints(bool value) {
    _controlPoints = value;
    isDirty = true;
  }

  set backgroundColor(Color color) {
    _backgroundColor = color;
    isDirty = true;
  }

  Color get backgroundColor => _backgroundColor;
}

abstract class Shape {
  String label;
  bool selected = false;
  Color color = Colors.black;
  double spacing = 10;

  Shape(this.label);

  void render(Canvas canvas, bool showLabels, bool showControlPoints);

  Hit? hitTest(Offset offset, double tolerance);
}

class Line extends Shape {
  Offset start;
  Offset end;

  Line(String label, this.start, this.end): super(label);

  @override
  void render(Canvas canvas, bool showLabels, bool showControlPoints) {
    Paint paint = Paint();
    if (selected) {
      paint.color = Colors.blue;
      paint.strokeWidth = 2;
    } else {
      paint.color = color;
      paint.strokeWidth = 1;
    }
    canvas.drawLine(start, end, paint);
    if (showLabels) {
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: Stage._textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2));
    }

    if (showControlPoints) {
      canvas.drawCircle(start, 5, paint);
      canvas.drawCircle(end, 5, paint);
    }

    if (selected) {
      Paint controlPaint = Paint();
      controlPaint.color = Colors.blue;
      controlPaint.strokeWidth = 1;

      canvas.drawCircle(start, 5, controlPaint);
      canvas.drawCircle(end, 5, controlPaint);
    }
  }

  @override
  Hit? hitTest(Offset offset, double tolerance) {
    if ((offset.dx - start.dx).abs() < tolerance && (offset.dy - start.dy).abs() < tolerance) {
      print('Hit $label at 0');
      return Hit(this, start, 0);
    }
    if ((offset.dx - end.dx).abs() < tolerance && (offset.dy - end.dy).abs() < tolerance) {
      print('Hit $label at 1');
      return Hit(this, end, 1);
    }

    return null;
    // double dx = end.dx - start.dx;
    // double dy = end.dy - start.dy;
    // double length = (dx * dx + dy * dy).sqrt();
    // double relativePosition = ((offset.dx - start.dx) * dx +
    //     (offset.dy - start.dy) * dy) / (length * length);
    // if (relativePosition < 0 || relativePosition > 1) {
    //   return null;
    // }
    // double x = start.dx + relativePosition * dx;
    // double y = start.dy + relativePosition * dy;
    // double distance = ((x - offset.dx) * (x - offset.dx) +
    //     (y - offset.dy) * (y - offset.dy)).sqrt();
    // if (distance > 5) {
    //   return null;
    // }
    // return Hit(this, Offset(x, y), relativePosition.toInt());
  }

  double length() {
    return (start - end).distance;
  }
}

class Circle extends Shape {
  Offset center;
  int radius;

  Circle(String label, this.center, this.radius): super(label);

  @override
  void render(Canvas canvas, bool showLabels, bool showControlPoints) {
    Paint paint = Paint();
    paint.color = Colors.black;
    paint.strokeWidth = 1;
    canvas.drawCircle(center, radius.toDouble(), paint);
    if (showLabels) {
      TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: Stage._textStyle,
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx, center.dy));
    }
  }

  @override
  Hit? hitTest(Offset offset, double tolerance) {
    double distance = ((center.dx - offset.dx) * (center.dx - offset.dx) +
        (center.dy - offset.dy) * (center.dy - offset.dy));
    if ((distance - radius.toDouble() * radius.toDouble()).abs() < tolerance * tolerance) {
      return Hit(this, center, 0);
    }
    return null;
  }
}


class Hit {
  final Shape shape;
  final Offset offset;
  final int relativePosition;

  Hit(this.shape, this.offset, this.relativePosition);

  void render(Canvas canvas) {
    Paint paint = Paint();
    paint.color = Colors.red;
    paint.strokeWidth = 1;
    canvas.drawCircle(offset, 5, paint);
  }
}

class Connection {
  Hit start;
  Hit end;
  bool selected = false;
  Color color = Colors.black;

  Connection(this.start, this.end);

  void render(Canvas canvas) {
    Line l1 = start.shape as Line;
    Line l2 = end.shape as Line;

    double nTicks1 =  l1.length() / l1.spacing;
    double delta1 = 1 / nTicks1;

    double nTicks2 =  l2.length() / l2.spacing;
    double delta2 = 1 / nTicks2;

    double l1x0 = start.relativePosition == 0 ? l1.start.dx : l1.end.dx;
    double l1y0 = start.relativePosition == 0 ? l1.start.dy : l1.end.dy;

    double l1x1 = start.relativePosition == 1 ? l1.start.dx : l1.end.dx;
    double l1y1 = start.relativePosition == 1 ? l1.start.dy : l1.end.dy;

    double l2x0 = end.relativePosition == 0 ? l2.start.dx : l2.end.dx;
    double l2y0 = end.relativePosition == 0 ? l2.start.dy : l2.end.dy;

    double l2x1 = end.relativePosition == 1 ? l2.start.dx : l2.end.dx;
    double l2y1 = end.relativePosition == 1 ? l2.start.dy : l2.end.dy;


    double startX = l1x0;
    double startY = l1y0;

    int tick = 0;

    Paint paint = Paint();
    paint.color = color;

    if (selected) {
      paint.strokeWidth = 3;
    }

    while (tick < nTicks1 && tick < nTicks2) {
      if (tick % 2 == 0) {
        double x = l2x0 + (l2x1 - l2x0) * (delta2 * tick);
        double y = l2y0 + (l2y1 - l2y0) * (delta2 * tick);
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
        startX = x;
        startY = y;
      } else {
        double x = l1x0 + (l1x1 - l1x0) * (delta1 * tick);
        double y = l1y0 + (l1y1 - l1y0) * (delta1 * tick);
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
        startX = x;
        startY = y;
      }
      tick++;
    }
  }
}

