import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/movie_section.dart';
import 'search_screen.dart';
import 'vod_category_screen.dart';
import 'movie_list_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'player_screen.dart';
import '../widgets/parallax_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ScrollController _scrollController = ScrollController();
  double _blurOpacity = 0.0;

  List<Movie> _trendingMovies = [];
  List<Movie> _chinesePopularTV = [];
  List<Movie> _chinesePopularMovies = [];
  List<Movie> _jkPopularTV = [];
  List<Movie> _topRatedMovies = [];

  bool _trendingLoading = true;
  bool _chineseTVLoading = true;
  bool _chineseMovieLoading = true;
  bool _jkTVLoading = true;
  bool _topRatedLoading = true;
  bool _hasInitError = false;

  Map<String, dynamic>? _lastWatched;
  bool _dismissedContinue = false;

  bool get _isAnyLoading =>
      _trendingLoading || _chineseTVLoading || _chineseMovieLoading || _jkTVLoading || _topRatedLoading;
  bool get _isAllEmpty =>
      _trendingMovies.isEmpty && _chinesePopularTV.isEmpty && _chinesePopularMovies.isEmpty && _jkPopularTV.isEmpty && _topRatedMovies.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadLastWatched();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadLastWatched() async {
    final history = await LocalStorageService.getHistory();
    if (history.isNotEmpty) {
      final last = history.first;
      final position = (last['position'] as num?)?.toDouble() ?? 0;
      if (position > 60) {
        if (mounted) setState(() => _lastWatched = last);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final newOpacity = (offset / 80).clamp(0.0, 1.0);
    if ((newOpacity - _blurOpacity).abs() > 0.01) {
      setState(() {
        _blurOpacity = newOpacity;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _trendingLoading = true;
      _chineseTVLoading = true;
      _chineseMovieLoading = true;
      _jkTVLoading = true;
      _topRatedLoading = true;
      _hasInitError = false;
    });

    Future<void> _fetchTrending() async {
      try {
        final data = await ApiService.getTrendingMovies();
        if (!mounted) return;
        setState(() {
          _trendingMovies = data;
          _trendingLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _trendingLoading = false);
      }
    }

    Future<void> _fetchChineseTV() async {
      try {
        final data = await ApiService.getChinesePopularTV();
        if (!mounted) return;
        setState(() {
          _chinesePopularTV = data;
          _chineseTVLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _chineseTVLoading = false);
      }
    }

    Future<void> _fetchChineseMovie() async {
      try {
        final data = await ApiService.getChinesePopularMovies();
        if (!mounted) return;
        setState(() {
          _chinesePopularMovies = data;
          _chineseMovieLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _chineseMovieLoading = false);
      }
    }

    Future<void> _fetchJKTV() async {
      try {
        final data = await ApiService.getJKPopularTV();
        if (!mounted) return;
        setState(() {
          _jkPopularTV = data;
          _jkTVLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _jkTVLoading = false);
      }
    }

    Future<void> _fetchTopRated() async {
      try {
        final data = await ApiService.getTopRatedMovies();
        if (!mounted) return;
        setState(() {
          _topRatedMovies = data;
          _topRatedLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _topRatedLoading = false);
      }
    }

    // Fire all requests concurrently; each settles independently.
    await Future.wait([
      _fetchTrending(),
      _fetchChineseTV(),
      _fetchChineseMovie(),
      _fetchJKTV(),
      _fetchTopRated(),
    ]);

    // If every request failed, show an error hint.
    if (mounted && _isAllEmpty && !_isAnyLoading) {
      setState(() => _hasInitError = true);
    }
  }

  Widget _buildContinueWatching() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final movie = Movie.fromJson(_lastWatched!);
    final epName = _lastWatched!['episodeName']?.toString() ?? '';
    final epText = epName.isNotEmpty ? ' - $epName' : '';
    final position = (_lastWatched!['position'] as num?)?.toDouble() ?? 0;
    final remaining = (position / 60).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, __, ___) => PlayerScreen(movie: movie),
            transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFE50914), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '继续观看',
                      style: TextStyle(
                        color: const Color(0xFFE50914),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '《${movie.title}》$epText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已观看至 ${remaining} 分钟',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _dismissedContinue = true;
                  _lastWatched = null;
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: theme.colorScheme.onSurface.withOpacity(0.35),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    final theme = Theme.of(context);
    if (_hasInitError && _isAllEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.signal_wifi_off, color: Color(0xFFE50914), size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                '网络似乎出了点问题',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _loadData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Text(
                    '重新加载',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFE50914),
      backgroundColor: theme.colorScheme.surface,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_trendingLoading)
              const SizedBox(
                height: 420,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914)),
                ),
              )
            else
              HeroBanner(movies: _trendingMovies),
            if (_lastWatched != null && !_dismissedContinue)
              _buildContinueWatching(),
            MovieSection(
              title: '热门国产剧',
              icon: '🇨🇳',
              movies: _chinesePopularTV,
              isLoading: _chineseTVLoading,
              onMoreTap: () {
                Navigator.push(context, PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (_, __, ___) => MovieListScreen(
                    title: '热门国产剧',
                    icon: '🇨🇳',
                    fetcher: ({page = 1}) => ApiService.getChinesePopularTV(page: page),
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                ));
              },
            ),
            MovieSection(
              title: '热门国产电影',
              icon: '🎬',
              movies: _chinesePopularMovies,
              isLoading: _chineseMovieLoading,
              onMoreTap: () {
                Navigator.push(context, PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (_, __, ___) => MovieListScreen(
                    title: '热门国产电影',
                    icon: '🎬',
                    fetcher: ({page = 1}) => ApiService.getChinesePopularMovies(page: page),
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                ));
              },
            ),
            MovieSection(
              title: '日韩潮流',
              icon: '🌊',
              movies: _jkPopularTV,
              isLoading: _jkTVLoading,
              onMoreTap: () {
                Navigator.push(context, PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (_, __, ___) => MovieListScreen(
                    title: '日韩潮流',
                    icon: '🌊',
                    fetcher: ({page = 1}) => ApiService.getJKPopularTV(page: page),
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                ));
              },
            ),
            MovieSection(
              title: '经典电影',
              icon: '🏆',
              movies: _topRatedMovies,
              isLoading: _topRatedLoading,
              onMoreTap: () {
                Navigator.push(context, PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 350),
                  reverseTransitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (_, __, ___) => MovieListScreen(
                    title: '经典电影',
                    icon: '🏆',
                    fetcher: ({page = 1}) => ApiService.getTopRatedMovies(page: page),
                  ),
                  transitionsBuilder: (_, animation, __, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: child,
                    ),
                ));
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPage() {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: const BoxDecoration(
                color: Color(0xFFE50914),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.4),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(text: '电视剧'),
                Tab(text: '电影'),
                Tab(text: '综艺'),
                Tab(text: '动漫'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _buildVodCategoryGrid(_tvCategories, 'tv'),
                _buildVodCategoryGrid(_movieCategories, 'movie'),
                _buildVodCategoryGrid(_varietyCategories, 'tv'),
                _buildVodCategoryGrid(_animeCategories, 'tv'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVodCategoryGrid(List<Map<String, dynamic>> categories, String type) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final color = _categoryColors[index % _categoryColors.length];
        return GestureDetector(
          onTap: () {
            Navigator.push(context, PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 350),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => VodCategoryScreen(
                typeId: cat['typeId'] as int,
                categoryName: cat['name'] as String,
                type: type,
              ),
              transitionsBuilder: (_, animation, __, child) =>
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(cat['icon'] as IconData, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat['name'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToListScreen(BuildContext context, Widget screen) {
    Navigator.push(context, PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, animation, __, child) =>
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
    ));
  }

  static const _tvCategories = [
    {'typeId': 13, 'name': '国产剧', 'icon': Icons.flag},
    {'typeId': 14, 'name': '香港剧', 'icon': Icons.landscape},
    {'typeId': 15, 'name': '韩国剧', 'icon': Icons.filter_vintage},
    {'typeId': 16, 'name': '欧美剧', 'icon': Icons.public},
    {'typeId': 21, 'name': '台湾剧', 'icon': Icons.park},
    {'typeId': 22, 'name': '日本剧', 'icon': Icons.ac_unit},
    {'typeId': 24, 'name': '泰国剧', 'icon': Icons.spa},
    {'typeId': 36, 'name': '短剧', 'icon': Icons.flash_on},
  ];

  static const _movieCategories = [
    {'typeId': 6, 'name': '动作片', 'icon': Icons.local_fire_department},
    {'typeId': 7, 'name': '喜剧片', 'icon': Icons.sentiment_satisfied},
    {'typeId': 8, 'name': '爱情片', 'icon': Icons.favorite},
    {'typeId': 9, 'name': '科幻片', 'icon': Icons.rocket_launch},
    {'typeId': 10, 'name': '恐怖片', 'icon': Icons.visibility_off},
    {'typeId': 11, 'name': '剧情片', 'icon': Icons.theater_comedy},
    {'typeId': 12, 'name': '战争片', 'icon': Icons.shield},
    {'typeId': 20, 'name': '记录片', 'icon': Icons.camera_alt},
  ];

  static const _varietyCategories = [
    {'typeId': 25, 'name': '大陆综艺', 'icon': Icons.live_tv},
    {'typeId': 26, 'name': '港台综艺', 'icon': Icons.tv},
    {'typeId': 27, 'name': '日韩综艺', 'icon': Icons.mic},
    {'typeId': 28, 'name': '欧美综艺', 'icon': Icons.language},
  ];

  static const _animeCategories = [
    {'typeId': 29, 'name': '国产动漫', 'icon': Icons.auto_awesome},
    {'typeId': 30, 'name': '日韩动漫', 'icon': Icons.animation},
    {'typeId': 31, 'name': '欧美动漫', 'icon': Icons.nights_stay},
    {'typeId': 32, 'name': '港台动漫', 'icon': Icons.toys},
    {'typeId': 33, 'name': '海外动漫', 'icon': Icons.explore},
  ];

  static const _categoryColors = [
    Color(0xFFFF4444),
    Color(0xFFFFAA00),
    Color(0xFF00D4FF),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF84CC16),
    Color(0xFFF97316),
    Color(0xFF34D399),
    Color(0xFFFB7185),
    Color(0xFF38BDF8),
  ];

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
          const _ProfileHeaderCard(),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _navigateToListScreen(context, const FavoritesScreen()),
            child: _buildProfileItem(Icons.bookmark, '我的收藏'),
          ),
          GestureDetector(
            onTap: () => _navigateToListScreen(context, const HistoryScreen()),
            child: _buildProfileItem(Icons.history, '观看历史'),
          ),
          const SizedBox(height: 16),
          _buildThemeSection(),
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF16161E) : Colors.white;
    final textColor = isDark ? const Color(0xFFE0E0E8) : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? const Color(0xFF5A5A6E) : const Color(0xFF9E9E9E);

    return Consumer<ThemeProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined, color: subtitleColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '外观设置',
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildThemeOption(
                icon: Icons.phone_android,
                title: '跟随系统',
                selected: provider.isSystem,
                onTap: () => provider.setThemeMode(ThemeMode.system),
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              _buildThemeOption(
                icon: Icons.dark_mode,
                title: '深色模式',
                selected: provider.isDark,
                onTap: () => provider.setThemeMode(ThemeMode.dark),
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
              _buildThemeOption(
                icon: Icons.light_mode,
                title: '浅色模式',
                selected: provider.isLight,
                onTap: () => provider.setThemeMode(ThemeMode.light),
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE50914).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? const Color(0xFFE50914) : subtitleColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: selected ? const Color(0xFFE50914) : textColor,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFFE50914), size: 20)
            else
              Icon(Icons.circle_outlined, color: subtitleColor.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 22),
        title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pages = [
      _buildHomePage(),
      _buildCategoryPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12 * _blurOpacity, sigmaY: 12 * _blurOpacity),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: theme.scaffoldBackgroundColor.withOpacity(0.65 * _blurOpacity),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter, color: Color(0xFFE50914), size: 26),
            SizedBox(width: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '视界',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  TextSpan(
                    text: 'MAX',
                    style: TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 400),
                    reverseTransitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
              child: Hero(
                tag: 'search_bar',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, color: isDark ? const Color(0xFFB0B0C0) : const Color(0xFF757575), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '搜索',
                        style: TextStyle(color: isDark ? const Color(0xFFB0B0C0) : const Color(0xFF757575), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.85),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashFactory: NoSplash.splashFactory,
                highlightColor: const Color(0xFFE50914).withOpacity(0.08),
              ),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: '首页',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: '发现',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: '我的',
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatefulWidget {
  const _ProfileHeaderCard();

  @override
  State<_ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends State<_ProfileHeaderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParallaxWidget(
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE50914), Color(0xFFCC0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withOpacity(_glowAnim.value),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.movie_filter, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (bounds) {
                    final t = _pulseController.value;
                    return LinearGradient(
                      colors: const [
                        Color(0xFFE50914),
                        Color(0xFFFF6B6B),
                        Color(0xFFFF4444),
                        Color(0xFFE50914),
                      ],
                      stops: [t - 0.3, t - 0.1, t + 0.1, t + 0.3].map((s) => s.clamp(0.0, 1.0)).toList(),
                    ).createShader(bounds);
                  },
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '视界',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                        TextSpan(
                          text: 'MAX',
                          style: TextStyle(
                            color: Color(0xFFE50914),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '畅享极致影视体验',
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, letterSpacing: 1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
