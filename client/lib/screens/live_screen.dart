import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/live_channel.dart';
import '../services/local_storage_service.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> with SingleTickerProviderStateMixin {
  int _selectedGroupIndex = 0;
  String? _selectedPlatform;
  List<LiveChannelGroup> _groups = List.from(builtinLiveGroups);
  List<LiveChannel> _customChannels = [];
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadCustomChannels();
  }

  Future<void> _loadCustomChannels() async {
    _customChannels = await LocalStorageService.getCustomLiveChannels();
    _rebuildGroups();
  }

  void _rebuildGroups() {
    setState(() {
      _groups = [
        ...builtinLiveGroups,
      ];
      if (_customChannels.isNotEmpty) {
        _groups.insert(0, LiveChannelGroup(name: '我的收藏', channels: List.from(_customChannels)));
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _getPlatforms() {
    final channels = _groups[_selectedGroupIndex].channels;
    final platforms = <String>{};
    for (final ch in channels) {
      if (ch.name.startsWith('B站')) {
        platforms.add('B站');
      } else if (ch.name.startsWith('虎牙')) {
        platforms.add('虎牙');
      } else if (ch.name.startsWith('斗鱼')) {
        platforms.add('斗鱼');
      } else {
        platforms.add('其他');
      }
    }
    return platforms.toList();
  }

  List<LiveChannel> _getFilteredChannels([int? groupIndex]) {
    final gi = groupIndex ?? _selectedGroupIndex;
    var channels = _groups[gi].channels;
    if (gi == _selectedGroupIndex && _selectedPlatform != null) {
      channels = channels.where((ch) {
        if (_selectedPlatform == '其他') {
          return !ch.name.startsWith('B站') && !ch.name.startsWith('虎牙') && !ch.name.startsWith('斗鱼');
        }
        return ch.name.startsWith(_selectedPlatform!);
      }).toList();
    }
    return channels;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  '放映厅',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddChannelDialog,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.add,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildGroupTabs(isDark),
          const SizedBox(height: 8),
          _buildPlatformTabs(isDark),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedGroupIndex = index;
                  _selectedPlatform = null;
                });
              },
              itemCount: _groups.length,
              itemBuilder: (context, groupIndex) {
                return _buildChannelGrid(isDark, groupIndex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTabs(bool isDark) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedGroupIndex == index;
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE50914)
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                _groups[index].name,
                style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlatformTabs(bool isDark) {
    final platforms = _getPlatforms();
    if (platforms.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 30,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: platforms.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final isSelected = isAll ? _selectedPlatform == null : _selectedPlatform == platforms[index - 1];
          final label = isAll ? '全部' : platforms[index - 1];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlatform = isAll ? null : platforms[index - 1];
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.12))
                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.black38),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelGrid(bool isDark, int groupIndex) {
    final channels = _getFilteredChannels(groupIndex);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final isCustom = _groups[groupIndex].name == '我的收藏';
        return Hero(
          tag: 'live_${channel.url}',
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => _playChannel(channel),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Stack(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _playChannel(channel),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: channel.logo != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: channel.logo!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Icon(
                                            Icons.play_circle_filled,
                                            color: Color(0xFFE50914),
                                            size: 20,
                                          ),
                                          errorWidget: (_, __, ___) => const Icon(
                                            Icons.play_circle_filled,
                                            color: Color(0xFFE50914),
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.play_circle_filled,
                                        color: Color(0xFFE50914),
                                        size: 20,
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      channel.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isCustom)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () async {
                            _customChannels.removeWhere((c) => c.url == channel.url);
                            await LocalStorageService.saveCustomLiveChannels(_customChannels);
                            _rebuildGroups();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: isDark ? Colors.white70 : Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _playChannel(LiveChannel channel) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _LivePlayerScreen(channel: channel);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _showAddChannelDialog() {
    final platforms = ['虎牙', '斗鱼', 'B站'];
    String selectedPlatform = platforms[0];
    final roomIdController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('新增直播间'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('平台', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: platforms.map((p) {
                      final isSelected = selectedPlatform == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedPlatform = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFE50914) : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              p,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('房间号', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roomIdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '输入直播间房间号',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text('备注（选填）', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: '给直播间起个名字',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final roomId = roomIdController.text.trim();
                    if (roomId.isEmpty) return;

                    String url;
                    String? logo;
                    switch (selectedPlatform) {
                      case '虎牙':
                        url = 'https://cdn-3.ttvb.eu.org/huya/$roomId';
                        logo = 'https://epg.yang-1989.eu.org/logo/虎牙.png';
                        break;
                      case '斗鱼':
                        url = 'https://cdn-3.ttvb.eu.org/douyu/$roomId';
                        logo = 'https://epg.yang-1989.eu.org/logo/斗鱼.png';
                        break;
                      case 'B站':
                        url = 'https://cdn-3.ttvb.eu.org/bilibili/$roomId';
                        logo = 'https://epg.yang-1989.eu.org/logo/哔哩哔哩.png';
                        break;
                      default:
                        url = 'https://cdn-3.ttvb.eu.org/huya/$roomId';
                        logo = null;
                    }

                    final note = noteController.text.trim();
                    final name = note.isNotEmpty
                        ? '$selectedPlatform $note'
                        : '$selectedPlatform $roomId';

                    final channel = LiveChannel(
                      name: name,
                      url: url,
                      logo: logo,
                      group: '我的收藏',
                    );

                    _customChannels.add(channel);
                    await LocalStorageService.saveCustomLiveChannels(_customChannels);
                    _rebuildGroups();

                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('添加', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _LivePlayerScreen extends StatefulWidget {
  final LiveChannel channel;

  const _LivePlayerScreen({required this.channel});

  @override
  State<_LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<_LivePlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  String? _error;
  bool _isFullscreen = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel.url),
        formatHint: VideoFormat.hls,
      );
      await _controller!.initialize();
      _controller!.play();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = '播放失败，请稍后重试';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Hero(
        tag: 'live_${widget.channel.url}',
        child: Material(
          color: Colors.black,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: _isInitializing
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFE50914)),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                                  const SizedBox(height: 12),
                                  Text(_error!, style: const TextStyle(color: Colors.white54)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isInitializing = true;
                                        _error = null;
                                      });
                                      _controller?.dispose();
                                      _initPlayer();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50914),
                                    ),
                                    child: const Text('重试'),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                ),
                if (_showControls) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 8,
                        right: 16,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              if (_isFullscreen) {
                                _toggleFullscreen();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.channel.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_controller != null && _controller!.value.isInitialized && _error == null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _controller!.value.isPlaying
                                    ? _controller!.pause()
                                    : _controller!.play();
                              });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              _controller!.seekTo(Duration.zero);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _toggleFullscreen,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
