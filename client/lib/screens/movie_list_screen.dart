import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

typedef MovieFetcher = Future<List<Movie>> Function({int page});

class MovieListScreen extends StatefulWidget {
  final String title;
  final String? icon;
  final MovieFetcher fetcher;

  const MovieListScreen({
    super.key,
    required this.title,
    this.icon,
    required this.fetcher,
  });

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  List<Movie> _movies = [];
  bool _isLoading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

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

      final movies = await widget.fetcher(page: _page);

      setState(() {
        if (_page == 1) {
          _movies = movies;
        } else {
          _movies.addAll(movies);
        }
        _hasMore = movies.length >= 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    _page++;
    await _loadData();
  }

  Future<void> _refresh() async {
    _page = 1;
    _hasMore = true;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(widget.icon!, style: const TextStyle(fontSize: 18)),
              ),
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _movies.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }

    if (_error != null && _movies.isEmpty) {
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
                '加载失败',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _refresh,
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
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _loadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.52,
            crossAxisSpacing: 14,
            mainAxisSpacing: 20,
          ),
          itemCount: _movies.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _movies.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2),
                ),
              );
            }
            return MovieCard(movie: _movies[index], width: double.infinity, height: 195);
          },
        ),
      ),
    );
  }
}
