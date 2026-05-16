import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final String type;
  final Movie? preview;
  final bool skipTmdb;

  const MovieDetailScreen({
    super.key,
    required this.movieId,
    this.type = 'movie',
    this.preview,
    this.skipTmdb = false,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with SingleTickerProviderStateMixin {
  Movie? _movie;
  bool _isLoading = true;
  bool _isFavorited = false;
  String? _error;
  final _vodSectionKey = GlobalKey();

  List<Map<String, dynamic>> _vodResults = [];
  bool _isLoadingVod = false;
  String? _vodError;
  int? _loadingVodId;
  late AnimationController _contentFadeController;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _contentFadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _contentFade = CurvedAnimation(
      parent: _contentFadeController,
      curve: Curves.easeOut,
    );
    _loadMovieDetails();
  }

  Future<void> _loadMovieDetails() async {
    // VOD category items have no TMDB counterpart — skip the lookup
    if (widget.skipTmdb) {
      setState(() => _isLoading = false);
      _contentFadeController.forward();
      _searchVodSources(widget.preview?.title ?? '');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final movie = widget.type == 'tv'
          ? await ApiService.getTVDetails(widget.movieId)
          : await ApiService.getMovieDetails(widget.movieId);

      final isFav = await LocalStorageService.isFavorite(movie.id);
      setState(() {
        _movie = movie;
        _isFavorited = isFav;
        _isLoading = false;
      });
      _contentFadeController.forward();
      _searchVodSources(movie.title);
    } catch (_) {
      // If we have preview data, use it and still search VOD
      if (widget.preview != null) {
        setState(() => _isLoading = false);
        _contentFadeController.forward();
        _searchVodSources(widget.preview!.title);
      } else {
        setState(() {
          _error = '加载失败';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchVodSources(String query) async {
    setState(() => _isLoadingVod = true);
    try {
      final results = await ApiService.multiSearchVod(query.trim());
      if (!mounted) return;
      setState(() {
        _vodResults = results;
        _isLoadingVod = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vodError = '搜索播放源失败';
        _isLoadingVod = false;
      });
    }
  }

  Future<void> _onVodResultTap(Map<String, dynamic> vodItem) async {
    final vodId = int.tryParse(vodItem['vodId']?.toString() ?? '');
    final siteKey = vodItem['siteKey']?.toString() ?? '';
    if (vodId == null || siteKey.isEmpty) return;

    setState(() => _loadingVodId = vodId);

    try {
      final result = await ApiService.getVodDetail(siteKey, vodId);
      if (!mounted) return;
      setState(() => _loadingVodId = null);

      if (!result.found || result.sources.isEmpty) {
        _showSnack('未找到可播放资源');
        return;
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              PlayerScreen(movie: _vodResultToMovie(vodItem, result)),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingVodId = null);
      _showSnack('加载失败');
    }
  }

  Movie _vodResultToMovie(Map<String, dynamic> vodItem, VodSearchResult vodDetail) {
    return Movie(
      id: int.tryParse(vodItem['vodId']?.toString() ?? '') ?? 0,
      title: vodDetail.title ?? vodItem['name'] ?? '',
      originalTitle: null,
      overview: vodDetail.description,
      posterUrl: vodDetail.poster,
      backdropUrl: null,
      rating: 0,
      releaseDate: vodDetail.year ?? '',
      type: (vodItem['typeName'] ?? '').toString().contains('剧') ? 'tv' : 'movie',
    );
  }

  String? _findVodCover(String vodName) {
    final movie = _movie;
    if (movie == null) return null;
    final lower = vodName.toLowerCase().trim();
    if (movie.title.toLowerCase().trim() == lower ||
        movie.originalTitle?.toLowerCase().trim() == lower) {
      return movie.posterUrl;
    }
    if (movie.title.toLowerCase().trim().contains(lower) ||
        lower.contains(movie.title.toLowerCase().trim())) {
      return movie.posterUrl;
    }
    return null;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE50914),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Movie get _displayMovie => _movie ?? widget.preview!;

  @override
  void dispose() {
    _contentFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading && widget.preview == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    if (_error != null && widget.preview == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _buildError(),
      );
    }

    if (_error != null && widget.preview != null) {
      // TMDB failed but we have preview data — show what we can
      final movie = widget.preview!;
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(movie),
            SliverToBoxAdapter(
              child: _buildContentBody(),
            ),
          ],
        ),
      );
    }

    final movie = _movie ?? widget.preview!;
    final isLoaded = _movie != null || widget.skipTmdb;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(movie),
          SliverToBoxAdapter(
            child: isLoaded
                ? FadeTransition(
                    opacity: _contentFade,
                    child: _buildContentBody(),
                  )
                : const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFE50914)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Movie movie) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _isFavorited ? Icons.bookmark : Icons.bookmark_border,
              color: _isFavorited ? const Color(0xFFE50914) : theme.colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () async {
              if (_movie == null) return;
              await LocalStorageService.toggleFavorite(_movie!);
              setState(() => _isFavorited = !_isFavorited);
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'movie_backdrop_${movie.id}',
              child: movie.backdropUrl != null
                  ? CachedNetworkImage(
                      imageUrl: movie.backdropUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: const Color(0xFF1A1A2E)),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1A1A2E),
                        child: const Icon(Icons.play_circle_outline, color: Color(0xFF3A3A4E), size: 64),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Icon(Icons.play_circle_outline, color: Color(0xFF3A3A4E), size: 64),
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.8, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Color(0xFFE50914), size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadMovieDetails,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                '重新加载',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentBody() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final movie = _movie ?? widget.preview!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'movie_poster_${movie.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: movie.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: movie.posterUrl!,
                                  width: 130,
                                  height: 195,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 130,
                                  height: 195,
                                  color: const Color(0xFF1A1A2E),
                                  child: const Icon(Icons.play_circle_outline, color: Color(0xFF3A3A4E)),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (movie.originalTitle != null && movie.originalTitle != movie.title)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                movie.originalTitle!,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE50914).withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      movie.rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (movie.releaseDate != null)
                            _buildInfoRow(Icons.calendar_today, movie.releaseDate!),
                          if (movie.runtime != null)
                            _buildInfoRow(Icons.schedule, '${movie.runtime} 分钟'),
                          if (movie.numberOfSeasons != null)
                            _buildInfoRow(Icons.tv, '${movie.numberOfSeasons} 季 · ${movie.numberOfEpisodes ?? '?'} 集'),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              final ctx = _vodSectionKey.currentContext;
                              if (ctx != null) {
                                Scrollable.ensureVisible(
                                  ctx,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  alignment: 0.0,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE50914).withOpacity(0.25),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '播放',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (movie.tagline != null && movie.tagline!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE50914).withOpacity(0.15)),
                    ),
                    child: Text(
                      '"${movie.tagline}"',
                      style: TextStyle(
                        color: const Color(0xFFFF6B6B).withOpacity(0.9),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Text(
                  '剧情简介',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  movie.overview ?? '暂无简介',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 28),
                if (movie.genres != null && movie.genres!.isNotEmpty) ...[
                  Text(
                    '类型标签',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: movie.genres!.map((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06 * 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08 * 0.7)),
                        ),
                        child: Text(
                          genre['name'] ?? '',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (movie.cast != null && movie.cast!.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildCastSection(movie.cast!),
                ],
                const SizedBox(height: 28),
                SizedBox(key: _vodSectionKey, child: _buildVodResultsSection()),
                const SizedBox(height: 60),
              ],
            ),
          );
  }

  Widget _buildCastSection(List<Map<String, dynamic>> cast) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '演职员',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = cast[index];
              final name = person['name']?.toString() ?? '';
              final character = person['character']?.toString() ?? '';
              final profileUrl = person['profileUrl']?.toString();
              final isDark = theme.brightness == Brightness.dark;
              return SizedBox(
                width: 90,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: profileUrl != null
                          ? CachedNetworkImage(
                              imageUrl: profileUrl,
                              width: 72,
                              height: 96,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _buildCastPlaceholder(name),
                            )
                          : _buildCastPlaceholder(name),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (character.isNotEmpty)
                      Text(
                        character,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCastPlaceholder(String name) {
    final theme = Theme.of(context);
    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 28,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildVodResultsSection() {
    final theme = Theme.of(context);

    if (_isLoadingVod) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE50914),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '正在搜索播放源...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_vodError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              _vodError!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_vodResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '未找到播放源',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_outline, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              '选择播放源',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${_vodResults.length} 个结果',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._vodResults.map((item) => _buildVodResultCard(item)),
      ],
    );
  }

  Widget _buildVodResultCard(Map<String, dynamic> item) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    final vodId = int.tryParse(item['vodId']?.toString() ?? '');
    final name = item['name']?.toString() ?? '';
    final typeName = item['typeName']?.toString() ?? '';
    final remark = item['remark']?.toString() ?? '';
    final siteName = item['siteName']?.toString() ?? '';
    final coverUrl = _findVodCover(name);
    final isLoading = _loadingVodId == vodId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: isLoading ? null : () => _onVodResultTap(item),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLoading
                ? const Color(0xFFE50914).withOpacity(0.08)
                : dark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLoading
                  ? const Color(0xFFE50914).withOpacity(0.2)
                  : dark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'movie_poster_${vodId ?? 0}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 92,
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildCoverPlaceholder(name),
                          )
                        : _buildCoverPlaceholder(name),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (typeName.isNotEmpty || remark.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (typeName.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                typeName,
                                style: const TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (typeName.isNotEmpty && remark.isNotEmpty)
                            const SizedBox(width: 6),
                          if (remark.isNotEmpty)
                            Expanded(
                              child: Text(
                                remark,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: t.colorScheme.onSurface.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.cloud_outlined, size: 12, color: t.colorScheme.onSurface.withOpacity(0.35)),
                        const SizedBox(width: 4),
                        Text(
                          siteName,
                          style: TextStyle(
                            color: t.colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE50914),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.play_circle_outline,
                    color: t.colorScheme.onSurface.withOpacity(0.3),
                    size: 28,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(String name) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
