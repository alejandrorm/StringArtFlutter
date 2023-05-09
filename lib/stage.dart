import 'package:flutter/material.dart';

class Stage {
  bool isDirty = true;
  bool _showLabels = false;
  bool _showConnections = false;
  bool _controlPoints = false;
  final Map<String, Shape> _shapes = {};
  List<Connection> connections = [];
  int ticks = 25;

  Hit? _hit;
  Line? _partialLine;
  Circle? _partialCircle;

  static const _textStyle = TextStyle(
    color: Colors.black,
    fontSize: 10,
  );

  void render(Canvas canvas) {
    for(Shape shape in _shapes.values) {
      shape.render(canvas, _showLabels, _controlPoints);
    }
    if (_showConnections) {
      for (Connection connection in connections) {
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

  void remove(Hit hit) {
    _shapes.remove(hit.shape.label);
    isDirty = true;
  }

  void renderTemp(Canvas canvas) {
    // _hit?.render(canvas);
    _partialLine?.render(canvas, false, true);
    _partialCircle?.render(canvas, false, false);
  }

  Hit? hitTest(Offset offset) {
    for (Shape shape in _shapes.values) {
      Hit? hit = shape.hitTest(offset);
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
}

abstract class Shape {
  String label;

  Shape(this.label);

  void render(Canvas canvas, bool showLabels, bool showControlPoints);

  Hit? hitTest(Offset offset);
}

class Line extends Shape {
  Offset start;
  Offset end;
  Color color = Colors.black;

  Line(String label, this.start, this.end): super(label);

  @override
  void render(Canvas canvas, bool showLabels, bool showControlPoints) {
    Paint paint = Paint();
    paint.color = color;
    paint.strokeWidth = 1;
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
      Paint controlPaint = Paint();
      controlPaint.color = Colors.red;
      controlPaint.strokeWidth = 1;

      canvas.drawCircle(start, 5, paint);
      canvas.drawCircle(end, 5, paint);
    }
  }

  @override
  Hit? hitTest(Offset offset) {
    if ((offset.dx - start.dx).abs() < 5 && (offset.dy - start.dy).abs() < 5) {
      print('Hit $label at 0');
      return Hit(this, start, 0);
    }
    if ((offset.dx - end.dx).abs() < 5 && (offset.dy - end.dy).abs() < 5) {
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
  Hit? hitTest(Offset offset) {
    double distance = ((center.dx - offset.dx) * (center.dx - offset.dx) +
        (center.dy - offset.dy) * (center.dy - offset.dy));
    if ((distance - radius.toDouble() * radius.toDouble()).abs() < 25) {
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

  Connection(this.start, this.end);

  void render(Canvas canvas) {

  }
}

