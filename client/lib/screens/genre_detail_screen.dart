import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import '../widgets/movie_card.dart';

class GenreDetailScreen extends StatefulWidget {
  final int genreId;
  final String genreName;
  final String type;

  const GenreDetailScreen({
    super.key,
    required this.genreId,
    required this.genreName,
    this.type = 'movie',
  });

  @override
  State<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends State<GenreDetailScreen> {
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

      List<Movie> movies;
      if (widget.type == 'tv') {
        movies = await ApiService.discoverTVByGenre(widget.genreId, page: _page);
      } else {
        movies = await ApiService.discoverMoviesByGenre(widget.genreId, page: _page);
      }

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
        title: Text(
          widget.genreName,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE50914), size: 40),
            const SizedBox(height: 16),
            const Text('加载失败', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
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
    );
  }
}
