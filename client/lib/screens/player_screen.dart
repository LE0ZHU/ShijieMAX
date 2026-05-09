import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final Movie movie;

  const PlayerScreen({super.key, required this.movie});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

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
    _savePosition();
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    _isFavorited = await LocalStorageService.isFavorite(movie.id);
    if (mounted) setState(() {});
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
    if (!_isPlayerReady || _isSwitching) return;
    try {
      final pos = _videoController.value.position.inSeconds.toDouble();
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

    try {
      final result = await ApiService.searchVod(
        movie.title,
        originalTitle: movie.originalTitle,
      );

      if (!result.found || result.sources.isEmpty) {
        setState(() {
          _vodError = '未找到可播放资源';
          _isLoadingVod = false;
        });
        return;
      }

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

      _videoController = VideoPlayerController.networkUrl(Uri.parse(playEp.url));
      await _videoController.initialize();

      if (startPosition != null) {
        await _videoController.seekTo(startPosition);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFE50914),
          handleColor: const Color(0xFFE50914),
          bufferedColor: Colors.white.withOpacity(0.3),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFE50914)),
          ),
        ),
      );

      await LocalStorageService.addToHistory(
        movie: movie,
        episodeIndex: startEpIdx,
        episodeName: playEp.name,
        sourceName: preferredSource.sourceName,
        position: startPosition?.inSeconds.toDouble() ?? 0,
      );

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

  Future<void> _switchVideo(String url) async {
    if (_isSwitching) return;
    _isSwitching = true;
    _stopPositionTracking();
    setState(() => _isPlayerReady = false);

    await _videoController.pause();
    _chewieController?.dispose();
    await _videoController.dispose();

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFFE50914),
        handleColor: const Color(0xFFE50914),
        bufferedColor: Colors.white.withOpacity(0.3),
        backgroundColor: Colors.white.withOpacity(0.1),
      ),
    );

    final ep = _selectedSource?.episodes;
    final epName = ep != null && _selectedEpisodeIndex < ep.length
        ? ep[_selectedEpisodeIndex].name : null;

    await LocalStorageService.updateHistoryPosition(
      movieId: movie.id,
      episodeIndex: _selectedEpisodeIndex,
      episodeName: epName,
    );

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _vodResult?.title ?? movie.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.bookmark : Icons.bookmark_border,
              color: _isFavorited ? const Color(0xFFE50914) : Colors.white,
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
                Text('正在搜索播放源...', style: TextStyle(color: Color(0xFFB0B0C0), fontSize: 13)),
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
                Text(_vodError!, style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 14)),
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
        ? _videoController.value.aspectRatio
        : 16 / 9;

    final maxHeight = MediaQuery.of(context).size.height * 0.5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final naturalHeight = width / aspectRatio;
        final height = naturalHeight > maxHeight ? maxHeight : naturalHeight;

        return SizedBox(
          width: width,
          height: height,
          child: _isPlayerReady
              ? Chewie(controller: _chewieController!)
              : Container(
                  color: Colors.black,
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
                ),
        );
      },
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
    final posterUrl = _vodResult?.poster ?? movie.posterUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: posterUrl != null
              ? CachedNetworkImage(imageUrl: posterUrl, width: 100, height: 150, fit: BoxFit.cover)
              : Container(
                  width: 100, height: 150, color: const Color(0xFF1A1A2E),
                  child: const Icon(Icons.play_circle_outline, color: Color(0xFF3A3A4E)),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vodResult?.title ?? movie.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Color(0xFFE50914)),
                  const SizedBox(width: 4),
                  Text(movie.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 13)),
                  if (movie.releaseDate != null) ...[
                    const SizedBox(width: 14),
                    const Icon(Icons.calendar_today, size: 12, color: Color(0xFF5A5A6E)),
                    const SizedBox(width: 4),
                    Text(movie.releaseDate!, style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 13)),
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
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF16161E),
                        title: Row(
                          children: [
                            const Text('简介', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF5A5A6E), size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: Text(
                            _vodResult?.description ?? movie.overview ?? '',
                            style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 14, height: 1.8),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    _vodResult?.description ?? movie.overview ?? '',
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('播放源', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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
                    color: isSelected ? const Color(0xFFE50914) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (source.hasM3u8) const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.hd, size: 14, color: Colors.white),
                      ),
                      Text(source.sourceName, style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFFB0B0C0),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list, size: 18, color: Color(0xFFE50914)),
            const SizedBox(width: 6),
            const Text('选集', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('共${episodes.length}集', style: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final ep = episodes[index];
            final isActive = index == _selectedEpisodeIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _onEpisodeSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFE50914).withOpacity(0.1) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isActive ? const Color(0xFFE50914).withOpacity(0.3) : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(ep.name, style: TextStyle(
                        color: isActive ? const Color(0xFFE50914) : Colors.white,
                        fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      )),
                      if (ep.isM3u8)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('M3U8', style: TextStyle(color: Color(0xFFE50914), fontSize: 10)),
                        ),
                      const Spacer(),
                      if (isActive)
                        const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 22),
                    ],
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
