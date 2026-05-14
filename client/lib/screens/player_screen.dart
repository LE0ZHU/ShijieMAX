import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/shijie_player.dart';

class PlayerScreen extends StatefulWidget {
  final Movie movie;

  const PlayerScreen({super.key, required this.movie});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;

  VodSearchResult? _vodResult;
  bool _isLoadingVod = true;
  String? _vodError;
  VodSource? _selectedSource;
  int _selectedEpisodeIndex = 0;
  bool _isFavorited = false;
  Timer? _positionTimer;

  bool _isPlayerReady = false;
  bool _isSwitching = false;

  Movie get movie => widget.movie;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    _initPlayer();
  }

  @override
  void dispose() {
    _stopPositionTracking();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    _isFavorited = await LocalStorageService.isFavorite(movie.id);
    if (mounted) setState(() {});
  }

  void _playNextEpisode() {
    final episodes = _selectedSource?.episodes ?? [];
    if (episodes.isEmpty) return;
    final nextIndex = _selectedEpisodeIndex + 1;
    if (nextIndex >= episodes.length) return;
    _onEpisodeSelected(nextIndex);
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 10), (_) => _savePosition());
  }

  void _stopPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _savePosition() async {
    final vc = _videoController;
    if (!_isPlayerReady || _isSwitching || vc == null) return;
    try {
      final pos = vc.value.position.inSeconds.toDouble();
      final ep = _selectedSource?.episodes;
      await LocalStorageService.updateHistoryPosition(
        movieId: movie.id,
        position: pos,
        episodeIndex: _selectedEpisodeIndex,
        episodeName: ep != null && _selectedEpisodeIndex < ep.length
            ? ep[_selectedEpisodeIndex].name : null,
      );
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    setState(() => _isLoadingVod = true);

    // Try cache first for instant loading
    final cached = await LocalStorageService.getCachedVod(movie.id);
    if (cached != null) {
      final result = VodSearchResult.fromJson(cached);
      if (result.found && result.sources.isNotEmpty) {
        final preferredSource = result.m3u8Sources.isNotEmpty
            ? result.m3u8Sources.first
            : result.sources.first;

        int startEpIdx = 0;
        Duration? startPosition;
        final history = await LocalStorageService.getHistoryForMovie(movie.id);
        if (history != null) {
          final savedEpIdx = history['episodeIndex'] as int? ?? 0;
          final savedPos = (history['position'] as num?)?.toDouble() ?? 0;
          if (savedEpIdx > 0 && savedEpIdx < preferredSource.episodes.length) {
            startEpIdx = savedEpIdx;
          }
          if (savedPos > 5) {
            startPosition = Duration(seconds: savedPos.toInt());
          }
        }

        final playEp = preferredSource.episodes[startEpIdx];
        final newController = VideoPlayerController.networkUrl(Uri.parse(playEp.url));
        _videoController = newController;
        await newController.initialize();

        if (!mounted) {
          newController.dispose();
          return;
        }

        if (startPosition != null) {
          await newController.seekTo(startPosition);
        }
        newController.play();

        await LocalStorageService.addToHistory(
          movie: movie,
          episodeIndex: startEpIdx,
          episodeName: playEp.name,
          sourceName: preferredSource.sourceName,
          position: startPosition?.inSeconds.toDouble() ?? 0,
        );

        if (!mounted) return;

        setState(() {
          _vodResult = result;
          _selectedSource = preferredSource;
          _selectedEpisodeIndex = startEpIdx;
          _isLoadingVod = false;
          _isPlayerReady = true;
        });
        _startPositionTracking();

        // Refresh cache in background
        _refreshVodCache();
        return;
      }
    }

    // No cache hit — load from network
    await _fetchVodFromNetwork();
  }

  Future<void> _fetchVodFromNetwork() async {
    try {
      final result = await ApiService.searchVod(
        movie.title,
        originalTitle: movie.originalTitle,
      );

      if (!result.found || result.sources.isEmpty) {
        if (!mounted) return;
        setState(() {
          _vodError = '未找到可播放资源';
          _isLoadingVod = false;
        });
        return;
      }

      if (!mounted) return;

      // Cache for next time
      LocalStorageService.cacheVodResult(movie.id, result);

      final preferredSource = result.m3u8Sources.isNotEmpty
          ? result.m3u8Sources.first
          : result.sources.first;

      int startEpIdx = 0;
      Duration? startPosition;

      final history = await LocalStorageService.getHistoryForMovie(movie.id);
      if (!mounted) return;
      if (history != null) {
        final savedEpIdx = history['episodeIndex'] as int? ?? 0;
        final savedPos = (history['position'] as num?)?.toDouble() ?? 0;
        if (savedEpIdx > 0 && savedEpIdx < preferredSource.episodes.length) {
          startEpIdx = savedEpIdx;
        }
        if (savedPos > 5) {
          startPosition = Duration(seconds: savedPos.toInt());
        }
      }

      final playEp = preferredSource.episodes[startEpIdx];

      final newController = VideoPlayerController.networkUrl(Uri.parse(playEp.url));
      _videoController = newController;
      await newController.initialize();

      if (!mounted) {
        newController.dispose();
        return;
      }

      if (startPosition != null) {
        await newController.seekTo(startPosition);
      }

      newController.play();

      await LocalStorageService.addToHistory(
        movie: movie,
        episodeIndex: startEpIdx,
        episodeName: playEp.name,
        sourceName: preferredSource.sourceName,
        position: startPosition?.inSeconds.toDouble() ?? 0,
      );

      if (!mounted) return;

      setState(() {
        _vodResult = result;
        _selectedSource = preferredSource;
        _selectedEpisodeIndex = startEpIdx;
        _isLoadingVod = false;
        _isPlayerReady = true;
      });

      _startPositionTracking();
    } catch (e) {
      setState(() {
        _vodError = e.toString();
        _isLoadingVod = false;
      });
    }
  }

  Future<void> _refreshVodCache() async {
    try {
      final result = await ApiService.searchVod(
        movie.title,
        originalTitle: movie.originalTitle,
      );
      if (result.found && result.sources.isNotEmpty) {
        LocalStorageService.cacheVodResult(movie.id, result);
      }
    } catch (_) {}
  }

  Future<void> _switchVideo(String url) async {
    if (_isSwitching) return;
    final vc = _videoController;
    if (vc == null) return;
    _isSwitching = true;
    _stopPositionTracking();
    setState(() => _isPlayerReady = false);

    await vc.pause();
    await vc.dispose();

    if (!mounted) return;

    final newController = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = newController;
    await newController.initialize();

    if (!mounted) {
      newController.dispose();
      return;
    }

    newController.play();

    final ep = _selectedSource?.episodes;
    final epName = ep != null && _selectedEpisodeIndex < ep.length
        ? ep[_selectedEpisodeIndex].name : null;

    await LocalStorageService.updateHistoryPosition(
      movieId: movie.id,
      episodeIndex: _selectedEpisodeIndex,
      episodeName: epName,
    );

    if (!mounted) return;

    _isSwitching = false;
    setState(() => _isPlayerReady = true);
    _startPositionTracking();
  }

  void _onEpisodeSelected(int index) {
    final episodes = _selectedSource?.episodes ?? [];
    if (index < 0 || index >= episodes.length || _isSwitching) return;

    _savePosition();
    setState(() => _selectedEpisodeIndex = index);
    _switchVideo(episodes[index].url);
  }

  void _onSourceSelected(VodSource source) {
    if (source.sourceName == _selectedSource?.sourceName || _isSwitching) return;

    _savePosition();
    setState(() {
      _selectedSource = source;
      _selectedEpisodeIndex = 0;
    });

    final firstEp = source.firstM3u8Episode ?? source.episodes.first;
    _switchVideo(firstEp.url);
  }

  void _retry() {
    setState(() {
      _vodError = null;
      _isLoadingVod = true;
    });
    _initPlayer();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildPlayer(),
            Expanded(child: _buildBottomSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _vodResult?.title ?? movie.title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.bookmark : Icons.bookmark_border,
              color: _isFavorited ? const Color(0xFFE50914) : theme.colorScheme.onSurface,
            ),
            onPressed: () async {
              await LocalStorageService.toggleFavorite(movie);
              setState(() => _isFavorited = !_isFavorited);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final theme = Theme.of(context);
    if (_isLoadingVod) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: SizedBox(
          width: double.infinity,
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFFE50914)),
                SizedBox(height: 12),
                Text('正在搜索播放源...', style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    if (_vodError != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: SizedBox(
          width: double.infinity,
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFE50914), size: 40),
                const SizedBox(height: 12),
                Text(_vodError!, style: const TextStyle(color: Color(0xFF999999), fontSize: 14)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _retry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('重试', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final aspectRatio = _isPlayerReady
        ? (_videoController?.value.aspectRatio ?? 16 / 9)
        : 16 / 9;

    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    final screenWidth = MediaQuery.of(context).size.width;
    final naturalHeight = screenWidth / aspectRatio;
    final rawHeight = naturalHeight > maxHeight ? maxHeight : naturalHeight;
    final height = (rawHeight + 48).clamp(0.0, maxHeight);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: _isPlayerReady
          ? ShijiePlayer(
              controller: _videoController!,
              onBack: () => Navigator.pop(context),
              onVideoEnd: _playNextEpisode,
              episodeName: _selectedSource?.episodes.isNotEmpty == true
                  ? _selectedSource!.episodes[_selectedEpisodeIndex].name
                  : null,
              placeholder: Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
              ),
            )
          : Container(
              color: Colors.black,
              child: const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
            ),
    );
  }

  Widget _buildBottomSection() {
    final episodes = _selectedSource?.episodes ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMovieInfo(),
          if (_vodResult != null && _vodResult!.sources.length > 1) ...[
            const SizedBox(height: 20),
            _buildSourceSelector(),
          ],
          if (episodes.length > 1) ...[
            const SizedBox(height: 20),
            _buildEpisodeSelector(episodes),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMovieInfo() {
    final theme = Theme.of(context);
    final posterUrl = _vodResult?.poster ?? movie.posterUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'movie_poster_${movie.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: posterUrl != null
                ? CachedNetworkImage(imageUrl: posterUrl, width: 100, height: 150, fit: BoxFit.cover)
                : Container(
                    width: 100, height: 150, color: theme.colorScheme.surface,
                    child: Icon(Icons.play_circle_outline, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vodResult?.title ?? movie.title,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Color(0xFFE50914)),
                  const SizedBox(width: 4),
                  Text(movie.rating.toStringAsFixed(1),
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                  if (movie.releaseDate != null) ...[
                    const SizedBox(width: 14),
                    Icon(Icons.calendar_today, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(movie.releaseDate!, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
                  ],
                ],
              ),
              if (_vodResult?.remark != null && _vodResult!.remark!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_vodResult!.remark!,
                      style: const TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
              if ((_vodResult?.description ?? movie.overview) != null &&
                  (_vodResult?.description ?? movie.overview)!.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        final dialogTheme = Theme.of(ctx);
                        return AlertDialog(
                          backgroundColor: dialogTheme.colorScheme.surface,
                          title: Row(
                            children: [
                              Text('简介', style: TextStyle(color: dialogTheme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.close, color: dialogTheme.colorScheme.onSurface.withOpacity(0.4), size: 20),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Text(
                              _vodResult?.description ?? movie.overview ?? '',
                              style: TextStyle(color: dialogTheme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14, height: 1.8),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: Text(
                    _vodResult?.description ?? movie.overview ?? '',
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSourceSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('播放源', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _vodResult!.sources.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final source = _vodResult!.sources[index];
              final isSelected = _selectedSource?.sourceName == source.sourceName;
              return GestureDetector(
                onTap: () => _onSourceSelected(source),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE50914) : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(18),
                    border: isSelected ? null : Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (source.hasM3u8) Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.hd, size: 14, color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      Text(source.sourceName, style: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeSelector(List<VodEpisode> episodes) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list, size: 18, color: Color(0xFFE50914)),
            const SizedBox(width: 6),
            Text('选集', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('共${episodes.length}集', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.0,
          ),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final ep = episodes[index];
            final isActive = index == _selectedEpisodeIndex;
            return GestureDetector(
              onTap: () => _onEpisodeSelected(index),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFE50914).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? const Color(0xFFE50914).withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                  ),
                ),
                child: Text(
                  ep.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? const Color(0xFFE50914) : theme.colorScheme.onSurface,
                    fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
