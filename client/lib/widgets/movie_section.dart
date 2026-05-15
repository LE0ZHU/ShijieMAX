import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../screens/movie_detail_screen.dart';
import 'movie_card.dart';
import 'parallax_widget.dart';

class HeroBanner extends StatefulWidget {
  final List<Movie> movies;
  final bool pauseAutoScroll;

  const HeroBanner({super.key, required this.movies, this.pauseAutoScroll = false});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  static const int _maxPageCount = 10000;
  int get _itemCount => widget.movies.length > 5 ? 5 : widget.movies.length;
  int get _startIndex => (_maxPageCount ~/ 2) - ((_maxPageCount ~/ 2) % _itemCount);

  void _startAutoScroll() {
    _stopAutoScroll();
    if (widget.pauseAutoScroll) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_itemCount <= 1) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _startIndex, viewportFraction: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  @override
  void didUpdateWidget(HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pauseAutoScroll && !oldWidget.pauseAutoScroll) {
      _stopAutoScroll();
    } else if (!widget.pauseAutoScroll && oldWidget.pauseAutoScroll) {
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 420,
      child: Stack(
        children: [
          GestureDetector(
            onPanDown: (_) => _stopAutoScroll(),
            onPanEnd: (_) => _startAutoScroll(),
            onPanCancel: () => _startAutoScroll(),
            child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index % _itemCount;
              });
            },
            itemCount: _itemCount > 1 ? _maxPageCount : 1,
            itemBuilder: (context, index) {
              final realIndex = index % _itemCount;
              final movie = widget.movies[realIndex];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 450),
                      reverseTransitionDuration: const Duration(milliseconds: 350),
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          MovieDetailScreen(movieId: movie.id, type: movie.type, preview: movie),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                              reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
                            ),
                          ),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: SizedBox.expand(
                  child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'movie_backdrop_${movie.id}',
                          child: movie.backdropUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: movie.backdropUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: const Color(0xFF1A1A2E),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: const Color(0xFF1A1A2E),
                                    child: const Icon(Icons.play_circle_outline, color: Color(0xFF3A3A4E), size: 48),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFF1A1A2E),
                                  child: const Icon(Icons.play_circle_outline, color: Color(0xFF3A3A4E), size: 48),
                                ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.3, 0.7, 1.0],
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: ParallaxWidget(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (movie.rating > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, size: 12, color: Colors.white),
                                        const SizedBox(width: 3),
                                        Text(
                                          movie.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Text(
                                  movie.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    shadows: [
                                      Shadow(color: Colors.black54, blurRadius: 8),
                                    ],
                                  ),
                                ),
                                if (movie.overview != null && movie.overview!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      movie.overview!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE50914).withOpacity(0.4),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow, size: 18, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text(
                                            '立即观看',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              );
            },
          ),
          ),
          if (widget.movies.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _itemCount,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? const Color(0xFFE50914) : Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MovieSection extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final bool isLoading;
  final String? icon;
  final VoidCallback? onMoreTap;

  const MovieSection({
    super.key,
    required this.title,
    required this.movies,
    this.isLoading = false,
    this.icon,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(icon!, style: const TextStyle(fontSize: 18)),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onMoreTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '更多',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 260,
          child: isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : movies.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: movies.length,
                      itemBuilder: (context, index) {
                        return MovieCard(movie: movies[index]);
                      },
                    ),
        ),
      ],
    );
  }
}
