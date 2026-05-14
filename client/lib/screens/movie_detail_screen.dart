import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final int movieId;
  final String type;
  final Movie? preview;

  const MovieDetailScreen({super.key, required this.movieId, this.type = 'movie', this.preview});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen>
    with SingleTickerProviderStateMixin {
  Movie? _movie;
  bool _isLoading = true;
  bool _isFavorited = false;
  String? _error;
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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _buildError(),
      );
    }

    final movie = _movie ?? widget.preview!;
    final isLoaded = _movie != null;

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
    final movie = _movie!;
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final movie = widget.preview ?? _movie!;
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  PlayerScreen(movie: movie),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withOpacity(0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.white, size: 22),
                              SizedBox(width: 6),
                              Text(
                                '立即播放',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                const SizedBox(height: 60),
              ],
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
