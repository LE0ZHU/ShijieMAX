import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/local_storage_service.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await LocalStorageService.getHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _remove(int movieId) async {
    await LocalStorageService.removeFromHistory(movieId);
    _load();
  }

  Future<void> _clear() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('清除记录', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text('确定要清空所有观看历史吗？', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: Color(0xFFE50914)))),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStorageService.clearHistory();
      _load();
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
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
        title: Text('观看历史', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          if (_history.isNotEmpty)
            IconButton(onPressed: _clear, icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 64),
                      const SizedBox(height: 16),
                      Text('暂无观看记录', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.46,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final movie = Movie.fromJson(item);
                    final time = _formatTime(item['watchedAt'] as String?);
                    final epName = item['episodeName']?.toString() ?? '';
                    final position = (item['position'] as num?)?.toDouble() ?? 0;
                    final hasProgress = position > 60;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 450),
                          reverseTransitionDuration: const Duration(milliseconds: 350),
                          pageBuilder: (c, a, sa) => PlayerScreen(movie: movie),
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
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: Icon(Icons.close, color: theme.colorScheme.onSurface, size: 14),
                                    ),
                                  ),
                                ),
                                if (hasProgress)
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: LinearProgressIndicator(
                                      value: (position % 3600) / 3600,
                                      backgroundColor: Colors.transparent,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                                      minHeight: 3,
                                    ),
                                  ),
                                Positioned(
                                  bottom: 4, right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow, size: 12, color: Colors.white),
                                        Text('继续', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                          if (epName.isNotEmpty)
                            Text(epName, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                          if (time.isNotEmpty && epName.isEmpty)
                            Text(time, style: const TextStyle(color: Color(0xFF5A5A6E), fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
