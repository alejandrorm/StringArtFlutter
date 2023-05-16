import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

class Stage {
  static const _textStyle = TextStyle(
    color: Colors.black,
    fontSize: 10,
  );

  bool isDirty = true;
  bool _showLabels = false;
  bool _showConnections = true;
  bool _controlPoints = false;
  Color _backgroundColor = Colors.white;
  final Map<String, Shape> _shapes = {};
  final List<Connection> _connections = [];

  final Queue<double> _minXStack = Queue();
  final Queue<double> _minYStack = Queue();
  final Queue<double> _maxXStack = Queue();
  final Queue<double> _maxYStack = Queue();

  int ticks = 25;
  Offset offset = Offset.zero;
  Hit? hit;
  Line? _partialLine;
  Circle? _partialCircle;

  Stage() {
    _minXStack.add(0);
    _minYStack.add(0);
    _maxXStack.add(0);
    _maxYStack.add(0);
  }

  Size get size => Size(_maxXStack.last - _minXStack.last,
                        _maxYStack.last - _minYStack.last);

  Rectangle get boundingBox =>
      Rectangle(_minXStack.last, _minYStack.last, size.width, size.height);

  void cancelPartialLine() {
    _partialLine = null;
  }

  void setHover(Hit hit) {
    this.hit = hit;
    isDirty = true;
  }

  void clearHover() {
    if (hit != null) {
      hit = null;
      isDirty = true;
    }
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

  void setTempCircle(Offset center, int radius) {
    _partialCircle = Circle('temp', center, radius);
  }

  void addLine(String label, Offset start, Offset end, double spacing) {
    double minX = min(_minXStack.last, min(start.dx, end.dx));
    double minY = min(_minYStack.last, min(start.dy, end.dy));
    double maxX = max(_maxXStack.last, max(start.dx, end.dx));
    double maxY = max(_maxYStack.last, max(start.dy, end.dy));

    _minXStack.add(minX);
    _minYStack.add(minY);
    _maxXStack.add(maxX);
    _maxYStack.add(maxY);

    _shapes[label] = Line(label, start, end);
    _shapes[label]!.spacing = spacing;
    _partialLine = null;
    isDirty = true;
  }

  void addCircle(String label, Offset center, int radius, double spacing) {
    double minX = min(_minXStack.last, center.dx - radius);
    double minY = min(_minYStack.last, center.dy - radius);
    double maxX = max(_maxXStack.last, center.dx + radius);
    double maxY = max(_maxYStack.last, center.dy + radius);

    _minXStack.add(minX);
    _minYStack.add(minY);
    _maxXStack.add(maxX);
    _maxYStack.add(maxY);

    _shapes[label] = Circle(label, center, radius);
    _shapes[label]!.spacing = spacing;
    _partialCircle = null;
    isDirty = true;
  }

  void removeShape(Shape shape) {
    _minXStack.removeLast();
    _minYStack.removeLast();
    _maxXStack.removeLast();
    _maxYStack.removeLast();

    _shapes.remove(shape.label);
    _connections.removeWhere((connection) => connection.start.shape == shape ||
                                             connection.end.shape == shape);
    isDirty = true;
  }

  void removeConnection(Connection connection) {
    _connections.remove(connection);
    isDirty = true;
  }

  void addConnection(Hit start, Hit end) {
    _connections.add(Connection(start, end));
    isDirty = true;
    _partialLine = null;
  }

  void renderTemp(Canvas canvas) {
    _partialLine?.selected = true;
    _partialLine?.render(canvas, false, true);
    _partialCircle?.selected = true;
    _partialCircle?.render(canvas, false, true);
    hit?.render(canvas);
  }

  Hit? hitTest(Offset offset, double tolerance) {
    for (Shape shape in _shapes.values) {
      Hit? hit = shape.hitTest(offset, tolerance);
      if (hit != null) {
        return hit;
      }
    }
    return null;
  }

  List<Connection> get connections => _connections;

  List<Shape> get shapes => _shapes.values.toList();

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

  Line? get partialLine => _partialLine;

  Circle? get partialCircle => _partialCircle;
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
      return Hit(this, start, 0);
    }
    if ((offset.dx - end.dx).abs() < tolerance && (offset.dy - end.dy).abs() < tolerance) {
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
    if (selected) {
      paint.color = Colors.blue;
      paint.strokeWidth = 2;
    } else {
      paint.color = color;
      paint.strokeWidth = 1;
    }
    paint.style = PaintingStyle.stroke;
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
    if (showControlPoints || selected) {
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(center, 5, paint);
      canvas.drawCircle(center + Offset(radius.toDouble(), 0), 5, paint);
    }
  }

  @override
  Hit? hitTest(Offset offset, double tolerance) {
    double distance = (center - offset).distance;
    if ((distance - radius.toDouble()).abs() < tolerance) {
      double t = getIntersection(offset);
      return Hit(this, getPointForParameter(t), t);
    }
    return null;
  }
  
  Offset getPointForParameter(double t) {
    double angle = t * 2 * pi;
    return Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle)); 
  }

  double getIntersection(Offset point) {
    if (point.dy == center.dy) {
      if (point.dx > center.dx) {
        return 0.0;
      } else {
        return 0.5;
      }
    } else {
      double m = (point.dy - center.dy) / (point.dx - center.dx);
      double alpha = atan(m);
      double t = alpha / (2 * pi) + 0.5;
      if (point.dx > center.dx) {
        t += 0.5;
      }
      if (t > 1.0) {
        t -= 1.0;
      }
      return t;
    }
  }
}


class Hit {
  final Shape shape;
  final Offset offset;
  final double relativePosition;

  Hit(this.shape, this.offset, this.relativePosition);

  void render(Canvas canvas) {
    Paint paint = Paint();
    paint.color = Colors.white;
    paint.strokeWidth = 1;
    canvas.drawCircle(offset, 5, paint);

    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawCircle(offset, 5, paint);
  }
}

class Connection {
  Hit start;
  Hit end;
  bool selected = false;
  Color color = Colors.black;

  int startSkipBy = 0;
  int startSkipEvery = 1;

  int endSkipBy = 0;
  int endSkipEvery = 1;

  Connection(this.start, this.end);

  void _renderLineConnection(Canvas canvas) {
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

    Paint paint = Paint();
    paint.color = color;

    if (selected) {
      paint.strokeWidth = 2;
    }

    int tick1 = 0;
    int tick2 = 0;
    while (tick1 <= nTicks1 && tick2 <= nTicks2) {
      if ((tick1 + tick2) % 2 == 0) {
        double x = l2x0 + (l2x1 - l2x0) * (delta2 * tick2);
        double y = l2y0 + (l2y1 - l2y0) * (delta2 * tick2);
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
        startX = x;
        startY = y;
        if (tick1 % startSkipEvery == 0) {
          tick1 += (1 + startSkipBy);
        } else {
          tick1++;
        }
      } else {
        double x = l1x0 + (l1x1 - l1x0) * (delta1 * tick1);
        double y = l1y0 + (l1y1 - l1y0) * (delta1 * tick1);
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
        startX = x;
        startY = y;
        if (tick2 % endSkipEvery == 0) {
          tick2 += (1 + endSkipBy);
        } else {
          tick2++;
        }
      }
    }
  }

  void _renderCircleConnection(Canvas canvas) {
    Circle c1 = start.shape as Circle;
    Circle c2 = end.shape as Circle;

    int nTicks1 =  c1.radius * 2 * pi ~/ c1.spacing;
    double delta1 = 1 / nTicks1;

    int nTicks2 =  c2.radius * 2 * pi ~/ c2.spacing;
    double delta2 = 1 / nTicks2;

    double t0 = start.relativePosition;
    double t1 = end.relativePosition;

    t0 = (nTicks1 * t0).toInt() * delta1;
    t1 = (nTicks2 * t1).toInt() * delta2;

    int tick = 0;
    Paint paint = Paint();
    paint.color = color;

    if (selected) {
      paint.strokeWidth = 2;
    }

    while (nTicks1 > 0 || nTicks2 > 0) {
      Offset p1 = c1.getPointForParameter(t0);
      Offset p2 = c2.getPointForParameter(t1);

      if (tick % 2 == 0) {
        canvas.drawLine(p1, p2, paint);
        if (nTicks1 % startSkipEvery == 0) {
          t0 += delta1 * (1 + startSkipBy);
          nTicks1 -= (1 + startSkipBy);
        } else {
          t0 += delta1;
          nTicks1 -= 1;
        }
      } else {
        canvas.drawLine(p2, p1, paint);
        if (nTicks2 % endSkipEvery == 0) {
          t1 += delta2 * (1 + endSkipBy);
          nTicks2 -= (1 + endSkipBy);
        } else {
          t1 += delta2;
          nTicks2 -= 1;
        }
      }
      tick++;
    }
  }

  void _renderLineCircleConnection(Hit line, Hit circle, Canvas canvas) {
    Line l = line.shape as Line;
    Circle c = circle.shape as Circle;

    double nTicks =  l.length() / l.spacing;
    double delta = 1 / nTicks;

    double lx0 = line.relativePosition == 0 ? l.start.dx : l.end.dx;
    double ly0 = line.relativePosition == 0 ? l.start.dy : l.end.dy;

    double lx1 = line.relativePosition == 1 ? l.start.dx : l.end.dx;
    double ly1 = line.relativePosition == 1 ? l.start.dy : l.end.dy;

    double cx = c.center.dx;
    double cy = c.center.dy;

    double r = c.radius.toDouble();

    double startX = lx0;
    double startY = ly0;

    int tick = 0;

    Paint paint = Paint();
    paint.color = color;

    if (selected) {
      paint.strokeWidth = 3;
    }

    while (tick < nTicks) {
      if (tick % 2 == 0) {
        // TODO: adjust for relative position
        double t = delta * tick;
        double x = lx0 + (lx1 - lx0) * t;
        double y = ly0 + (ly1 - ly0) * t;
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
        startX = x;
        startY = y;
      } else {
        double t = delta * tick;
        double angle = t * 2 * pi;
        double x = cx + r * cos(angle);
        double y = cy + r * sin(angle);
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
        startX = x;
        startY = y;
      }
      tick++;
    }
  }

  void render(Canvas canvas) {
    if (start.shape is Line && end.shape is Line) {
      _renderLineConnection(canvas);
    } else if (start.shape is Circle && end.shape is Circle) {
      _renderCircleConnection(canvas);
    } else if (start.shape is Line) {
      _renderLineCircleConnection(start, end, canvas);
    } else {
      _renderLineCircleConnection(end, start, canvas);
    }
  }
}

