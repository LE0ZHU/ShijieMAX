import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ParallaxWidget extends StatefulWidget {
  final Widget child;
  final double offset;

  const ParallaxWidget({
    super.key,
    required this.child,
    this.offset = 8.0,
  });

  @override
  State<ParallaxWidget> createState() => _ParallaxWidgetState();
}

class _ParallaxWidgetState extends State<ParallaxWidget> {
  double _x = 0;
  double _y = 0;
  StreamSubscription<AccelerometerEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen((event) {
        final targetX = event.x.clamp(-4.0, 4.0) / 4.0;
        final targetY = event.y.clamp(-4.0, 4.0) / 4.0;
        setState(() {
          _x = _x + (targetX - _x) * 0.1;
          _y = _y + (targetY - _y) * 0.1;
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(_x * widget.offset, _y * widget.offset),
      child: widget.child,
    );
  }
}
