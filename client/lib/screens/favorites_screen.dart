import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/local_storage_service.dart';
import 'movie_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Movie> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await LocalStorageService.getFavorites();
    setState(() {
      _movies = favs;
      _isLoading = false;
    });
  }

  Future<void> _remove(int movieId) async {
    await LocalStorageService.removeFavorite(movieId);
    _load();
  }

  Future<void> _clearAll() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('清除收藏', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('确定要清空所有收藏吗？', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Color(0xFFE50914)))),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStorageService.clearFavorites();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06 * 0.7), shape: BoxShape.circle),
            child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('我的收藏', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_movies.isNotEmpty)
            IconButton(onPressed: _clearAll, icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _movies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 64),
                      const SizedBox(height: 16),
                      Text('暂无收藏', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.48,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _movies.length,
                  itemBuilder: (context, index) {
                    final movie = _movies[index];
                    return GestureDetector(
                      onTap: () async {
                        await Navigator.push(context, PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 450),
                          reverseTransitionDuration: const Duration(milliseconds: 350),
                          pageBuilder: (c, a, sa) => MovieDetailScreen(movieId: movie.id, type: movie.type),
                          transitionsBuilder: (c, a, sa, child) {
                            return FadeTransition(
                              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: a,
                                  curve: Curves.easeOut,
                                  reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
                                ),
                              ),
                              child: child,
                            );
                          },
                        ));
                        _load();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 2 / 3,
                            child: Stack(
                              children: [
                                Hero(
                                  tag: 'movie_poster_${movie.id}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: movie.posterUrl != null
                                        ? CachedNetworkImage(imageUrl: movie.posterUrl!, fit: BoxFit.cover, width: double.infinity)
                                        : Container(color: const Color(0xFF1A1A2E), child: const Icon(Icons.movie, color: Color(0xFF3A3A4E))),
                                  ),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: GestureDetector(
                                    onTap: () => _remove(movie.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                      child: Icon(Icons.close, color: theme.colorScheme.onSurface, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
