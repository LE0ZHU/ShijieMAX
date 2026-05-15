import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum _RefreshStatus { idle, pulling, ready, refreshing, error }

class ShijieRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerPullDistance;
  final double maxPullDistance;
  final double indicatorHeight;
  final VoidCallback? onPullActive;
  final VoidCallback? onPullIdle;

  const ShijieRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerPullDistance = 60.0,
    this.maxPullDistance = 100.0,
    this.indicatorHeight = 44.0,
    this.onPullActive,
    this.onPullIdle,
  });

  @override
  State<ShijieRefreshIndicator> createState() => _ShijieRefreshIndicatorState();
}

class _ShijieRefreshIndicatorState extends State<ShijieRefreshIndicator>
    with TickerProviderStateMixin {
  double _pullDistance = 0.0;
  _RefreshStatus _status = _RefreshStatus.idle;
  ScrollPosition? _scrollPosition;
  bool _isHoldingRefresh = false;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;
  late AnimationController _loadingController;
  double _snapStartValue = 0.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..addListener(_onSnapTick);
    _snapAnimation = CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOut,
    );
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _snapController.removeListener(_onSnapTick);
    _snapController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    setState(() {
      _pullDistance = _snapStartValue * (1.0 - _snapAnimation.value);
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    // Cache the scroll position on first encounter
    if (_scrollPosition == null &&
        notification.metrics is ScrollPosition) {
      _scrollPosition = notification.metrics as ScrollPosition;
    }

    // Only react to our own scrollable
    if (_scrollPosition != null &&
        !identical(notification.metrics, _scrollPosition)) {
      return false;
    }

    if (_status == _RefreshStatus.refreshing) {
      _holdRefreshPosition();
      return false;
    }

    // Primary path: OverscrollNotification fires for BouncingScrollPhysics
    if (notification is OverscrollNotification) {
      if (notification.overscroll > 0) {
        final wasIdle = _status == _RefreshStatus.idle;
        setState(() {
          _pullDistance =
              notification.overscroll.clamp(0.0, widget.maxPullDistance);
          _status = _pullDistance >= widget.triggerPullDistance
              ? _RefreshStatus.ready
              : _RefreshStatus.pulling;
        });
        if (wasIdle && _status != _RefreshStatus.idle) {
          _notifyPullActive();
        }
      }
      return false;
    }

    // Fallback path: some scroll physics report negative pixels directly
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels < 0) {
      final wasIdle = _status == _RefreshStatus.idle;
      setState(() {
        _pullDistance =
            (-notification.metrics.pixels).clamp(0.0, widget.maxPullDistance);
        _status = _pullDistance >= widget.triggerPullDistance
            ? _RefreshStatus.ready
            : _RefreshStatus.pulling;
      });
      if (wasIdle && _status != _RefreshStatus.idle) {
        _notifyPullActive();
      }
      return false;
    }

    // Detect finger lift
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        _onUserReleased();
      }
    }

    return false;
  }

  void _holdRefreshPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isHoldingRefresh && _scrollPosition != null) {
        _scrollPosition!.jumpTo(-widget.triggerPullDistance);
      }
    });
  }

  void _onUserReleased() {
    if (_pullDistance >= widget.triggerPullDistance &&
        _status == _RefreshStatus.ready) {
      _startRefresh();
    } else if (_pullDistance > 0) {
      _resetToIdle();
    }
  }

  void _notifyPullActive() {
    widget.onPullActive?.call();
  }

  void _notifyPullIdle() {
    widget.onPullIdle?.call();
  }

  void _startRefresh() {
    setState(() {
      _status = _RefreshStatus.refreshing;
    });
    _loadingController.repeat();
    _isHoldingRefresh = true;

    widget.onRefresh().then((_) {
      if (!mounted) return;
      _finishRefresh();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _status = _RefreshStatus.error);
      _loadingController.stop();
      _isHoldingRefresh = false;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _resetToIdle();
      });
    });
  }

  void _finishRefresh() {
    if (!mounted) return;
    _isHoldingRefresh = false;
    _loadingController.stop();
    _resetToIdle();
  }

  void _resetToIdle() {
    setState(() => _status = _RefreshStatus.idle);
    _snapStartValue = _pullDistance;
    _snapController.forward(from: 0.0);
    _notifyPullIdle();
  }

  // ── Visual helpers ──

  double get _pillOpacity =>
      (_pullDistance / (widget.triggerPullDistance * 0.5)).clamp(0.0, 1.0);

  double get _pillScale => 0.85 + 0.15 * _pillOpacity;

  double get _chevronAngle =>
      (_pullDistance / widget.triggerPullDistance).clamp(0.0, 1.0) * pi;

  String _statusText() {
    switch (_status) {
      case _RefreshStatus.pulling:
        return '下拉刷新';
      case _RefreshStatus.ready:
        return '释放刷新';
      case _RefreshStatus.refreshing:
        return '正在刷新...';
      case _RefreshStatus.error:
        return '刷新失败';
      case _RefreshStatus.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.08);
    final textColor =
        isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E);
    const accentColor = Color(0xFFE50914);
    final showIndicator =
        (_status != _RefreshStatus.idle && _pullDistance > 0) ||
            _status == _RefreshStatus.refreshing ||
            _status == _RefreshStatus.error;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: widget.child,
        ),
        if (showIndicator)
          Positioned(
            top: (_pullDistance - widget.indicatorHeight).clamp(0.0, 80.0),
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _pillOpacity,
                  child: Transform.scale(
                    scale: _pillScale,
                    child: Container(
                      height: widget.indicatorHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius:
                            BorderRadius.circular(widget.indicatorHeight / 2),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(
                                _status == _RefreshStatus.refreshing
                                    ? 0.15
                                    : 0.06),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: _status == _RefreshStatus.refreshing
                                ? _ArcLoader(
                                    controller: _loadingController,
                                    color: accentColor,
                                  )
                                : Transform.rotate(
                                    angle: _chevronAngle,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: _status == _RefreshStatus.error
                                          ? const Color(0xFFFF4444)
                                          : accentColor,
                                      size: 22,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _statusText(),
                            style: TextStyle(
                              color: _status == _RefreshStatus.error
                                  ? const Color(0xFFFF4444)
                                  : textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ArcLoader extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _ArcLoader({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _ArcPainter(
          value: controller.value,
          color: color,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;

  _ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startAngle = -pi / 2 + value * 2 * pi;
    const sweepAngle = pi * 0.75;

    canvas.drawArc(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
