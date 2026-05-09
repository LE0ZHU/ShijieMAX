import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'player_screen.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';

class VodCategoryScreen extends StatefulWidget {
  final int typeId;
  final String categoryName;
  final String type;

  const VodCategoryScreen({
    super.key,
    required this.typeId,
    required this.categoryName,
    this.type = 'tv',
  });

  @override
  State<VodCategoryScreen> createState() => _VodCategoryScreenState();
}

class _VodCategoryScreenState extends State<VodCategoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  int? _loadingVodId;

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

      final items = await ApiService.getVodCategory(widget.typeId, page: _page);

      setState(() {
        if (_page == 1) {
          _items = items;
        } else {
          _items.addAll(items);
        }
        _hasMore = items.length >= 20;
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

  Future<void> _onItemTap(Map<String, dynamic> item) async {
    final vodId = int.tryParse(item['vodId']?.toString() ?? '');
    if (vodId == null) return;

    setState(() => _loadingVodId = vodId);

    try {
      final result = await ApiService.getVodDetail('ffzy', vodId);
      if (!mounted) return;
      setState(() => _loadingVodId = null);

      if (!result.found || result.sources.isEmpty) {
        _showSnack('未找到可播放资源');
        return;
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, a, sa) => PlayerScreen(movie: Movie(
            id: vodId,
            title: result.title ?? item['name'] ?? '',
            posterUrl: result.poster,
            overview: result.description,
            rating: 0,
            releaseDate: result.year,
            type: widget.type,
          )),
          transitionsBuilder: (c, a, sa, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingVodId = null);
      _showSnack('加载失败');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914), duration: const Duration(seconds: 2)),
    );
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE50914), size: 40),
            const SizedBox(height: 16),
            const Text('加载失败', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (info) {
        if (info.metrics.pixels >= info.metrics.maxScrollExtent - 200) _loadMore();
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.52,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2)));
          }
          return _buildCard(_items[index]);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final vodId = int.tryParse(item['vodId']?.toString() ?? '');
    final name = item['name']?.toString() ?? '';
    final pic = item['pic']?.toString() ?? '';
    final remark = item['remark']?.toString() ?? '';
    final isLoading = _loadingVodId == vodId;

    return GestureDetector(
      onTap: isLoading ? null : () => _onItemTap(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (pic.isNotEmpty)
                      CachedNetworkImage(imageUrl: pic, fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildPlaceholder(name))
                    else
                      _buildPlaceholder(name),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        )),
                      ),
                    ),
                    if (remark.isNotEmpty)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(remark, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFE0E0E8), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String name) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Text(name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(color: Color(0xFF3A3A4E), fontSize: 32, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
