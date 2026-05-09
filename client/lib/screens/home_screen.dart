import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../widgets/movie_section.dart';
import 'search_screen.dart';
import 'vod_category_screen.dart';
import 'movie_list_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Movie> _trendingMovies = [];
  List<Movie> _trendingTV = [];
  List<Movie> _nowPlayingMovies = [];
  List<Movie> _upcomingMovies = [];
  List<Movie> _topRatedMovies = [];
  List<Movie> _topRatedTV = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        ApiService.getTrendingMovies(),
        ApiService.getTrendingTV(),
        ApiService.getNowPlayingMovies(),
        ApiService.getUpcomingMovies(),
        ApiService.getTopRatedMovies(),
        ApiService.getTopRatedTV(),
      ]);

      setState(() {
        _trendingMovies = results[0];
        _trendingTV = results[1];
        _nowPlayingMovies = results[2];
        _upcomingMovies = results[3];
        _topRatedMovies = results[4];
        _topRatedTV = results[5];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildHomePage() {
    if (_error != null) {
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
              const Text(
                '网络似乎出了点问题',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
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
      backgroundColor: const Color(0xFF16161E),
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const SizedBox(
                height: 420,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFE50914)),
                ),
              )
            else
              HeroBanner(movies: _trendingMovies),
            MovieSection(
              title: '经典电影',
              icon: '🏆',
              movies: _topRatedMovies,
              isLoading: _isLoading,
              onMoreTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListScreen(
                  title: '经典电影',
                  icon: '🏆',
                  fetcher: ({page = 1}) => ApiService.getTopRatedMovies(page: page),
                )));
              },
            ),
            MovieSection(
              title: '经典电视剧',
              icon: '⭐',
              movies: _topRatedTV,
              isLoading: _isLoading,
              onMoreTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListScreen(
                  title: '经典电视剧',
                  icon: '⭐',
                  fetcher: ({page = 1}) => ApiService.getTopRatedTV(page: page),
                )));
              },
            ),
            MovieSection(
              title: '热门电影',
              icon: '🎬',
              movies: _trendingMovies,
              isLoading: _isLoading,
              onMoreTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListScreen(
                  title: '热门电影',
                  icon: '🎬',
                  fetcher: ({page = 1}) => ApiService.getTrendingMovies(page: page),
                )));
              },
            ),
            MovieSection(
              title: '正在上映',
              icon: '🍿',
              movies: _nowPlayingMovies,
              isLoading: _isLoading,
              onMoreTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListScreen(
                  title: '正在上映',
                  icon: '🍿',
                  fetcher: ({page = 1}) => ApiService.getNowPlayingMovies(page: page),
                )));
              },
            ),
            MovieSection(
              title: '即将上映',
              icon: '📅',
              movies: _upcomingMovies,
              isLoading: _isLoading,
              onMoreTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListScreen(
                  title: '即将上映',
                  icon: '📅',
                  fetcher: ({page = 1}) => ApiService.getUpcomingMovies(page: page),
                )));
              },
            ),
            MovieSection(
              title: '热门电视剧',
              icon: '📺',
              movies: _trendingTV,
              isLoading: _isLoading,
              onMoreTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MovieListScreen(
                  title: '热门电视剧',
                  icon: '📺',
                  fetcher: ({page = 1}) => ApiService.getTrendingTV(page: page),
                )));
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPage() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF16161E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Color(0xFFE50914),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF5A5A6E),
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VodCategoryScreen(
                  typeId: cat['typeId'] as int,
                  categoryName: cat['name'] as String,
                  type: type,
                ),
              ),
            );
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF16161E),
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
                  ),
                  child: const Icon(Icons.movie_filter, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text.rich(
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
                const SizedBox(height: 8),
                const Text(
                  '畅享极致影视体验',
                  style: TextStyle(color: Color(0xFF5A5A6E), fontSize: 13, letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())),
            child: _buildProfileItem(Icons.bookmark, '我的收藏'),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            child: _buildProfileItem(Icons.history, '观看历史'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFB0B0C0), size: 22),
        title: Text(title, style: const TextStyle(color: Color(0xFFE0E0E8), fontSize: 15, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF5A5A6E), size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomePage(),
      _buildCategoryPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
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
                      color: Colors.white,
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
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 300),
                  pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFE50914),
          unselectedItemColor: const Color(0xFF5A5A6E),
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
    );
  }
}
