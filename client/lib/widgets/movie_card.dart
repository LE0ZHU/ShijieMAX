import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../screens/movie_detail_screen.dart';
import 'parallax_widget.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final double width;
  final double height;

  const MovieCard({
    super.key,
    required this.movie,
    this.width = 130,
    this.height = 195,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Hero(
                  tag: 'movie_poster_${movie.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        movie.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl: movie.posterUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.surface,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFE50914),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: theme.colorScheme.surface,
                                child: Icon(Icons.play_circle_outline, color: theme.colorScheme.onSurface.withOpacity(0.2), size: 36),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surface,
                              child: Icon(Icons.play_circle_outline, color: theme.colorScheme.onSurface.withOpacity(0.2), size: 36),
                            ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (movie.rating > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: ParallaxWidget(
                            offset: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE50914).withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, size: 10, color: Colors.white),
                                  const SizedBox(width: 2),
                                  Text(
                                    movie.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
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
                ),
              ),
            ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (movie.releaseDate != null && movie.releaseDate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 2),
                child: Text(
                  movie.releaseDate!.substring(0, movie.releaseDate!.length > 4 ? 4 : movie.releaseDate!.length),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
