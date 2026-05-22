import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';

class ShijiePlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final Widget? placeholder;
  final VoidCallback? onBack;
  final VoidCallback? onVideoEnd;
  final String? episodeName;

  const ShijiePlayer({
    super.key,
    required this.controller,
    this.placeholder,
    this.onBack,
    this.onVideoEnd,
    this.episodeName,
  });

  @override
  State<ShijiePlayer> createState() => _ShijiePlayerState();
}

// ── Shared player logic mixin ──────────────────────────────────

mixin _PlayerControllerMixin<T extends StatefulWidget> on State<T> {
  VideoPlayerController get ctl;

  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _uiTimer;
  double _playbackSpeed = 1.0;

  double _startDx = 0;
  double _startDy = 0;
  bool _isSeeking = false;
  double _startVolume = 1.0;
  double _startBrightness = 0.5;
  bool _isAdjusting = false;
  bool _isVolumeAdjust = false;
  bool _isSeekingForward = false;
  String _adjustHint = '';
  double _seekTargetMs = 0;

  late AnimationController _playIconController;
  late Animation<double> _playIconAnim;

  static const speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  void initPlayerMixin() {
    _playIconController = AnimationController(
      vsync: this as TickerProvider,
      duration: const Duration(milliseconds: 300),
    );
    _playIconAnim = CurvedAnimation(parent: _playIconController, curve: Curves.easeOut);
    ctl.addListener(_onCtlUpdate);
    _startUiTimer();
    _startAutoHide();
    _initBrightness();
  }

  void disposePlayerMixin() {
    ctl.removeListener(_onCtlUpdate);
    _hideTimer?.cancel();
    _uiTimer?.cancel();
    _playIconController.dispose();
    _restoreBrightness();
  }

  Future<void> _initBrightness() async {
    try {
      _startBrightness = await ScreenBrightness().application;
    } catch (_) {
      _startBrightness = 0.5;
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {}
  }

  void _onCtlUpdate() {
    if (mounted) setState(() {});
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startAutoHide() {
    _hideTimer?.cancel();
    if (!ctl.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) setState(() => _showControls = false);
    });
  }

  void toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        if (ctl.value.isPlaying) _startAutoHide();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void togglePlay() {
    if (ctl.value.isPlaying) {
      ctl.pause();
    } else {
      ctl.play();
    }
    _playIconController.forward(from: 0);
    _startAutoHide();
    setState(() {});
  }

  void setPlaybackSpeed(double speed) {
    ctl.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  void onPanStart(DragStartDetails d, Size size) {
    _startDx = d.localPosition.dx;
    _startDy = d.localPosition.dy;
    _isSeeking = false;
    _isAdjusting = false;
    _startVolume = (ctl.value.volume * 100).round() / 100;
    _seekTargetMs = ctl.value.position.inMilliseconds.toDouble();
  }

  void onPanUpdate(DragUpdateDetails d, Size size) {
    final dx = d.localPosition.dx - _startDx;
    final accumulatedDy = _startDy - d.localPosition.dy;

    if (!_isAdjusting && dx.abs() > 8) {
      _isSeeking = true;
      _isSeekingForward = dx > 0;
      final dur = ctl.value.duration.inMilliseconds.toDouble();
      _seekTargetMs = (_seekTargetMs + dx * 80).clamp(0.0, dur);
      _startDx = d.localPosition.dx;
      final target = Duration(milliseconds: _seekTargetMs.round());
      _adjustHint = '${fmtSeek(target)} / ${fmtSeek(ctl.value.duration)}';
      setState(() {});
    }

    if (!_isSeeking && accumulatedDy.abs() > 8) {
      _isAdjusting = true;
      final ratio = accumulatedDy / (size.height * 0.6);
      if (d.localPosition.dx > size.width * 0.65) {
        final newVol = (_startVolume + ratio).clamp(0.0, 1.0);
        ctl.setVolume(newVol);
        _isVolumeAdjust = true;
        _adjustHint = '${(newVol * 100).round()}%';
      } else if (d.localPosition.dx < size.width * 0.35) {
        final newBright = (_startBrightness + ratio).clamp(0.0, 1.0);
        ScreenBrightness().setApplicationScreenBrightness(newBright);
        _startBrightness = newBright;
        _isVolumeAdjust = false;
        _adjustHint = '${(newBright * 100).round()}%';
      }
      setState(() {});
    }
  }

  void onPanEnd(DragEndDetails d) {
    if (_isSeeking) {
      ctl.seekTo(Duration(milliseconds: _seekTargetMs.round()));
    }
    _isSeeking = false;
    _isAdjusting = false;
    _adjustHint = '';
    _startAutoHide();
  }

  static String fmtSeek(Duration d) {
    final h = d.inHours.abs();
    final m = d.inMinutes.abs().remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.abs().remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String fmtTime(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Inline player state ────────────────────────────────────────

class _ShijiePlayerState extends State<ShijiePlayer> with TickerProviderStateMixin, _PlayerControllerMixin<ShijiePlayer> {
  bool _isFullscreenActive = false;
  bool _videoEndedInFullscreen = false;

  @override
  VideoPlayerController get ctl => widget.controller;

  @override
  void initState() {
    super.initState();
    initPlayerMixin();
  }

  @override
  void _onCtlUpdate() {
    if (mounted) setState(() {});
    if (!ctl.value.isCompleted) return;
    if (_isFullscreenActive) {
      _videoEndedInFullscreen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    widget.onVideoEnd?.call();
  }

  @override
  void dispose() {
    disposePlayerMixin();
    super.dispose();
  }

  Future<void> _enterFullscreen() async {
    _hideTimer?.cancel();
    _uiTimer?.cancel();
    _isFullscreenActive = true;

    final isPortrait = ctl.value.aspectRatio > 0 && ctl.value.aspectRatio < 1;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (isPortrait) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    if (!mounted) return;

    await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (c, a, sa) => _FullscreenPlayer(
          controller: ctl,
          isPortrait: isPortrait,
          episodeName: widget.episodeName,
          onExit: () => Navigator.of(c).pop(true),
        ),
        transitionsBuilder: (c, a, sa, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    if (!mounted) return;

    _isFullscreenActive = false;

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    if (_videoEndedInFullscreen) {
      _videoEndedInFullscreen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVideoEnd?.call();
      });
      return;
    }

    if (!mounted) return;
    _startUiTimer();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerOverlay(
      controller: ctl,
      showControls: _showControls,
      isLocked: false,
      isFullscreen: false,
      playIconAnim: _playIconAnim,
      playIconController: _playIconController,
      adjustHint: _adjustHint,
      isVolumeAdjust: _isVolumeAdjust,
      isSeeking: _isSeeking,
      isSeekingForward: _isSeekingForward,
      onToggleControls: toggleControls,
      onTogglePlay: togglePlay,
      onEnterFullscreen: _enterFullscreen,
      onBack: widget.onBack,
      episodeName: widget.episodeName,
      playbackSpeed: _playbackSpeed,
      onSpeedChanged: setPlaybackSpeed,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
    );
  }
}

// ── Fullscreen page ────────────────────────────────────────────

class _FullscreenPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onExit;
  final bool isPortrait;
  final String? episodeName;

  const _FullscreenPlayer({required this.controller, required this.onExit, this.isPortrait = false, this.episodeName});

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> with TickerProviderStateMixin, _PlayerControllerMixin<_FullscreenPlayer> {
  bool _isLocked = false;

  @override
  VideoPlayerController get ctl => widget.controller;

  @override
  void initState() {
    super.initState();
    initPlayerMixin();
  }

  @override
  void dispose() {
    disposePlayerMixin();
    super.dispose();
  }

  @override
  void toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        if (_isLocked) {
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showControls = false);
          });
        } else if (ctl.value.isPlaying) {
          _startAutoHide();
        }
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _showControls = true;
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showControls = false);
        });
      } else {
        _showControls = true;
        _startAutoHide();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _PlayerOverlay(
        controller: ctl,
        showControls: _showControls,
        isLocked: _isLocked,
        isFullscreen: true,
        playIconAnim: _playIconAnim,
        playIconController: _playIconController,
        adjustHint: _adjustHint,
        isVolumeAdjust: _isVolumeAdjust,
        isSeeking: _isSeeking,
        isSeekingForward: _isSeekingForward,
        onToggleControls: toggleControls,
        onTogglePlay: togglePlay,
        onEnterFullscreen: widget.onExit,
        onBack: null,
        episodeName: widget.episodeName,
        playbackSpeed: _playbackSpeed,
        onSpeedChanged: setPlaybackSpeed,
        onPanStart: _isLocked ? null : onPanStart,
        onPanUpdate: _isLocked ? null : onPanUpdate,
        onPanEnd: _isLocked ? null : onPanEnd,
        onToggleLock: _toggleLock,
      ),
    );
  }
}

// ── Shared overlay UI ──────────────────────────────────────────

class _PlayerOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  final bool showControls;
  final bool isLocked;
  final bool isFullscreen;
  final Animation<double> playIconAnim;
  final AnimationController playIconController;
  final String adjustHint;
  final bool isVolumeAdjust;
  final bool isSeeking;
  final bool isSeekingForward;
  final VoidCallback onToggleControls;
  final VoidCallback onTogglePlay;
  final VoidCallback onEnterFullscreen;
  final VoidCallback? onBack;
  final void Function(DragStartDetails, Size)? onPanStart;
  final void Function(DragUpdateDetails, Size)? onPanUpdate;
  final void Function(DragEndDetails)? onPanEnd;
  final VoidCallback? onToggleLock;
  final String? episodeName;
  final double playbackSpeed;
  final ValueChanged<double>? onSpeedChanged;

  const _PlayerOverlay({
    required this.controller,
    required this.showControls,
    required this.isLocked,
    required this.isFullscreen,
    required this.playIconAnim,
    required this.playIconController,
    required this.adjustHint,
    required this.isVolumeAdjust,
    required this.isSeeking,
    required this.isSeekingForward,
    required this.onToggleControls,
    required this.onTogglePlay,
    required this.onEnterFullscreen,
    this.onBack,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onToggleLock,
    this.episodeName,
    this.playbackSpeed = 1.0,
    this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ctl = controller;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
        // Video fills the area
        Center(
          child: isFullscreen
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: ctl.value.size.width,
                    height: ctl.value.size.height,
                    child: VideoPlayer(ctl),
                  ),
                )
              : AspectRatio(
                  aspectRatio: ctl.value.aspectRatio > 0 ? ctl.value.aspectRatio : 16 / 9,
                  child: VideoPlayer(ctl),
                ),
        ),

        // Gesture layer
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onToggleControls,
              onDoubleTap: onTogglePlay,
              onPanStart: onPanStart != null ? (d) => onPanStart!(d, size) : null,
              onPanUpdate: onPanUpdate != null ? (d) => onPanUpdate!(d, size) : null,
              onPanEnd: onPanEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Center icons
                  if (showControls)
                    Center(
                      child: isLocked && onToggleLock != null
                          ? GestureDetector(
                              onTap: onToggleLock,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                child: const Icon(Icons.lock, color: Colors.white, size: 28),
                              ),
                            )
                          : GestureDetector(
                              onTap: onTogglePlay,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 1.4, end: 1.0).animate(playIconAnim),
                                  child: Icon(
                                    ctl.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                    ),

                  // Buffering indicator
                  if (ctl.value.isBuffering)
                    const Center(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFE50914),
                        ),
                      ),
                    ),

                  // Top bar
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    top: showControls && !isLocked ? 0 : -80,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 56 + (isFullscreen ? MediaQuery.of(context).padding.top : 0),
                      padding: EdgeInsets.only(top: isFullscreen ? MediaQuery.of(context).padding.top : 0),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: isFullscreen ? onEnterFullscreen : onBack,
                          ),
                          if (episodeName != null && episodeName!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                episodeName!,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),

                  // Lock button (separate from top bar, with right padding to avoid system gestures)
                  if (isFullscreen && onToggleLock != null)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      top: showControls && !isLocked
                          ? (isFullscreen ? MediaQuery.of(context).padding.top : 0) + 4
                          : -80,
                      right: MediaQuery.of(context).padding.right +
                          MediaQuery.of(context).systemGestureInsets.right +
                          8,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: Icon(isLocked ? Icons.lock : Icons.lock_open, color: Colors.white, size: 22),
                          onPressed: onToggleLock,
                        ),
                      ),
                    ),

                  // Bottom bar
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    bottom: showControls && !isLocked ? 0 : -120,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SeekBar(controller: ctl, onSeekEnd: () {}),
                          const SizedBox(height: 0),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(ctl.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 26),
                                onPressed: onTogglePlay,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36),
                              ),
                              const SizedBox(width: 4),
                              Text(_PlayerControllerMixin.fmtTime(ctl.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Text(' / ${_PlayerControllerMixin.fmtTime(ctl.value.duration)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const Spacer(),
                              if (onSpeedChanged != null)
                                _SpeedButton(speed: playbackSpeed, onChanged: onSpeedChanged!),
                              IconButton(
                                icon: Icon(isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 22),
                                onPressed: onEnterFullscreen,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Adjust hint
                  if (adjustHint.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSeeking
                                  ? (isSeekingForward ? Icons.forward_10 : Icons.replay_10)
                                  : isVolumeAdjust
                                      ? Icons.volume_up
                                      : Icons.brightness_6,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(adjustHint, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
      ),
    );
  }
}

// ── Speed button ───────────────────────────────────────────────

class _SpeedButton extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;

  const _SpeedButton({required this.speed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = speed == 1.0 ? '倍速' : '${speed}x';
    return GestureDetector(
      onTap: () => _showSpeedMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showSpeedMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<double>(
      context: context,
      backgroundColor: isDark ? Colors.black87 : Colors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        maxWidth: 280,
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _PlayerControllerMixin.speedOptions.map((s) {
          final isActive = s == speed;
          return InkWell(
            onTap: () {
              onChanged(s);
              Navigator.pop(ctx);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s == 1.0 ? '${s.toStringAsFixed(0)}x 正常' : '${s}x',
                      style: TextStyle(
                        color: isActive ? const Color(0xFFE50914) : (isDark ? Colors.white : Colors.black87),
                        fontSize: 16,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isActive)
                    const Icon(Icons.check, color: Color(0xFFE50914), size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Seek bar ──────────────────────────────────────────────────

class _SeekBar extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onSeekEnd;

  const _SeekBar({required this.controller, required this.onSeekEnd});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.controller;
    final dur = ctl.value.duration.inMilliseconds.toDouble();
    final pos = ctl.value.position.inMilliseconds.toDouble();
    final buffered = ctl.value.buffered.isNotEmpty
        ? ctl.value.buffered.last.end.inMilliseconds.toDouble()
        : 0.0;
    final actualValue = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    final bufValue = dur > 0 ? (buffered / dur).clamp(0.0, 1.0) : 0.0;
    final displayValue = _isDragging ? _dragValue : actualValue;
    final canSeek = dur > 0;

    // Time preview for drag bubble
    final previewMs = (dur * displayValue).toInt();
    final previewText = _PlayerControllerMixin.fmtTime(Duration(milliseconds: previewMs));

    return SizedBox(
      height: _isDragging ? 32 : 14,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: canSeek ? (d) {
          final w = context.size?.width ?? 0;
          if (w <= 0) return;
          final ratio = (d.localPosition.dx / w).clamp(0.0, 1.0);
          ctl.seekTo(Duration(milliseconds: (dur * ratio).toInt()));
          widget.onSeekEnd();
        } : null,
        onHorizontalDragStart: canSeek ? (d) {
          final w = context.size?.width ?? 0;
          if (w <= 0) return;
          setState(() {
            _isDragging = true;
            _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
          });
        } : null,
        onHorizontalDragUpdate: canSeek ? (d) {
          final w = context.size?.width ?? 0;
          if (w <= 0) return;
          setState(() {
            _dragValue = (d.localPosition.dx / w).clamp(0.0, 1.0);
          });
        } : null,
        onHorizontalDragEnd: canSeek ? (_) {
          ctl.seekTo(Duration(milliseconds: (dur * _dragValue).toInt()));
          setState(() => _isDragging = false);
          widget.onSeekEnd();
        } : null,
        child: CustomPaint(
          painter: _SeekBarPainter(
            value: displayValue,
            bufferedValue: bufValue,
            isDragging: _isDragging,
            previewText: _isDragging ? previewText : null,
          ),
          size: Size(double.infinity, _isDragging ? 32 : 14),
        ),
      ),
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  final double value;
  final double bufferedValue;
  final bool isDragging;
  final String? previewText;

  _SeekBarPainter({
    required this.value,
    required this.bufferedValue,
    this.isDragging = false,
    this.previewText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackH = isDragging ? 4.0 : 3.0;
    final thumbR = isDragging ? 8.0 : 6.0;
    final trackCenterY = isDragging ? size.height - 16.0 : size.height - thumbR;
    final trackY = trackCenterY - trackH / 2;
    final playedW = size.width * value;
    final bufW = size.width * bufferedValue;

    // Buffered
    canvas.drawRRect(
      RRect.fromLTRBR(0, trackY, bufW, trackY + trackH, const Radius.circular(2)),
      Paint()..color = Colors.white24,
    );
    // Played
    canvas.drawRRect(
      RRect.fromLTRBR(0, trackY, playedW, trackY + trackH, const Radius.circular(2)),
      Paint()..color = const Color(0xFFE50914),
    );
    // Thumb
    canvas.drawCircle(Offset(playedW, trackCenterY), thumbR, Paint()..color = const Color(0xFFE50914));

    // Time preview bubble when dragging
    if (isDragging && previewText != null) {
      final bubbleW = 44.0;
      final bubbleH = 22.0;
      final bubbleR = 6.0;
      final bubbleX = (playedW - bubbleW / 2).clamp(0.0, size.width - bubbleW);
      final bubbleY = trackCenterY - thumbR - 8 - bubbleH;

      final bubbleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bubbleX, bubbleY, bubbleW, bubbleH),
        Radius.circular(bubbleR),
      );
      canvas.drawRRect(bubbleRect, Paint()..color = const Color(0xFFE50914));

      // Small triangle pointer
      final pointerX = playedW.clamp(bubbleX + 6, bubbleX + bubbleW - 6);
      final pointerPath = Path()
        ..moveTo(pointerX - 4, bubbleY + bubbleH)
        ..lineTo(pointerX + 4, bubbleY + bubbleH)
        ..lineTo(pointerX, bubbleY + bubbleH + 5)
        ..close();
      canvas.drawPath(pointerPath, Paint()..color = const Color(0xFFE50914));

      // Text
      final tp = TextPainter(
        text: TextSpan(
          text: previewText,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(bubbleX + (bubbleW - tp.width) / 2, bubbleY + (bubbleH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _SeekBarPainter old) =>
      value != old.value || bufferedValue != old.bufferedValue || isDragging != old.isDragging || previewText != old.previewText;
}
