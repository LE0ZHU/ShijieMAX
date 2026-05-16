import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';
import '../services/api_service.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _vodResults = [];
  List<Movie> _tmdbResults = [];
  bool _isLoading = false;
  String? _error;
  bool _hasSearched = false;
  int? _loadingVodId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _hasSearched = true;
      _vodResults = [];
      _tmdbResults = [];
    });

    try {
      final results = await Future.wait([
        ApiService.multiSearchVod(query.trim()),
        ApiService.search(query.trim()).catchError((_) => <Movie>[]),
      ]);

      setState(() {
        _vodResults = results[0] as List<Map<String, dynamic>>;
        _tmdbResults = results[1] as List<Movie>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String? _findTmdbCover(String vodName) {
    final lower = vodName.toLowerCase().trim();
    for (final m in _tmdbResults) {
      if (m.title.toLowerCase().trim() == lower ||
          m.originalTitle?.toLowerCase().trim() == lower) {
        return m.posterUrl;
      }
    }
    // Partial match: TMDB title contains VOD name or vice versa
    for (final m in _tmdbResults) {
      final mt = m.title.toLowerCase().trim();
      if (mt.contains(lower) || lower.contains(mt)) {
        return m.posterUrl;
      }
    }
    return null;
  }

  Future<void> _onResultTap(Map<String, dynamic> vodItem) async {
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
          pageBuilder: (context, animation, secondaryAnimation) =>
              PlayerScreen(movie: _vodResultToMovie(vodItem, result)),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingVodId = null);
      _showSnack('加载失败: $e');
    }
  }

  Movie _vodResultToMovie(Map<String, dynamic> vodItem, VodSearchResult vodDetail) {
    return Movie(
      id: int.tryParse(vodItem['vodId']?.toString() ?? '') ?? 0,
      title: vodDetail.title ?? vodItem['name'] ?? '',
      originalTitle: null,
      overview: vodDetail.description,
      posterUrl: vodDetail.poster ?? _findTmdbCover(vodItem['name'] ?? ''),
      backdropUrl: null,
      rating: 0,
      releaseDate: vodDetail.year ?? '',
      type: (vodItem['typeName'] ?? '').toString().contains('剧') ? 'tv' : 'movie',
    );
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
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Hero(
          tag: 'search_bar',
          child: Material(
            type: MaterialType.transparency,
            child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: '搜索电影、电视剧...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 14),
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _vodResults = [];
                            _tmdbResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onSubmitted: _performSearch,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _performSearch(_searchController.text),
              child: const Text(
                '搜索',
                style: TextStyle(color: Color(0xFFE50914), fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE50914)),
      );
    }

    if (_error != null) {
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
              '搜索失败',
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildInitialHint();
    }

    if (_vodResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation_outlined, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 72),
            const SizedBox(height: 16),
            Text(
              '未找到相关结果',
              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vodResults.length,
      itemBuilder: (context, index) {
        return _buildResultCard(_vodResults[index]);
      },
    );
  }

  Widget _buildInitialHint() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 72),
          const SizedBox(height: 16),
          Text(
            '输入关键词搜索全网资源',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '漫威', '星际穿越', '宫崎骏', '哈利波特',
              '速度与激情', '爱情公寓', '甄嬛传', '庆余年',
            ].map((label) => _buildQuickSearch(label)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearch(String label) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _performSearch(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
        ),
        child: Text(
          label,
          style: TextStyle(color: t.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    final vodId = int.tryParse(item['vodId']?.toString() ?? '');
    final name = item['name']?.toString() ?? '';
    final typeName = item['typeName']?.toString() ?? '';
    final remark = item['remark']?.toString() ?? '';
    final siteName = item['siteName']?.toString() ?? '';
    final tmdbCover = _findTmdbCover(name);
    final isLoading = _loadingVodId == vodId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: isLoading ? null : () => _onResultTap(item),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLoading
                ? const Color(0xFFE50914).withOpacity(0.08)
                : dark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04 * 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLoading
                  ? const Color(0xFFE50914).withOpacity(0.2)
                  : dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06 * 0.7),
            ),
          ),
          child: Row(
            children: [
              // Cover / placeholder
              Hero(
                tag: 'movie_poster_${vodId ?? 0}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 70,
                    height: 100,
                    child: tmdbCover != null
                        ? CachedNetworkImage(
                            imageUrl: tmdbCover,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.colorScheme.onSurface,
                        fontSize: 15,
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
                            Text(
                              remark,
                              style: TextStyle(
                                color: t.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (siteName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.cloud, size: 11, color: t.colorScheme.onSurface.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Text(
                            siteName,
                            style: TextStyle(
                              color: t.colorScheme.onSurface.withOpacity(0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  child: Icon(Icons.play_circle_outline, color: t.colorScheme.onSurface.withOpacity(0.3), size: 28),
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
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
