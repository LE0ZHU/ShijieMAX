import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';
import '../models/vod_source.dart';

class ApiService {
  // static const String baseUrl = 'http://192.168.31.176:3003'; // 本地
  static const String baseUrl = 'http://117.72.217.70:3003'; // 服务器

  static bool _parseSuccess(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  static List<Movie> _parseMovieList(dynamic rawData) {
    if (rawData is List) {
      return rawData.map((item) => Movie.fromJson(item)).toList();
    }
    if (rawData is Map && rawData.containsKey('results')) {
      final results = rawData['results'];
      if (results is List) {
        return results.map((item) => Movie.fromJson(item)).toList();
      }
    }
    return [];
  }

  static Future<List<Movie>> _fetchList(String path, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path${path.contains('?') ? '&' : '?'}page=$page'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return _parseMovieList(data['data']);
      }
    }
    throw Exception('Failed to load data from $path: ${response.statusCode}');
  }

  static Future<List<Movie>> getTrendingMovies({String timeWindow = 'week', int page = 1}) async {
    return _fetchList('/api/trending/movies?timeWindow=$timeWindow', page: page);
  }

  static Future<List<Movie>> getTrendingTV({String timeWindow = 'week', int page = 1}) async {
    return _fetchList('/api/trending/tv?timeWindow=$timeWindow', page: page);
  }

  static Future<List<Movie>> getNowPlayingMovies({int page = 1}) async {
    return _fetchList('/api/movies/now-playing', page: page);
  }

  static Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    return _fetchList('/api/movies/upcoming', page: page);
  }

  static Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    return _fetchList('/api/movies/top-rated', page: page);
  }

  static Future<List<Movie>> getTopRatedTV({int page = 1}) async {
    return _fetchList('/api/tv/top-rated', page: page);
  }

  static Future<List<Movie>> getPopularMovies({int page = 1}) async {
    return _fetchList('/api/movies/popular', page: page);
  }

  static Future<List<Movie>> getChinesePopularMovies({int page = 1}) async {
    return _fetchList('/api/movies/chinese-popular', page: page);
  }

  static Future<List<Movie>> getChinesePopularTV({int page = 1}) async {
    return _fetchList('/api/tv/chinese-popular', page: page);
  }

  static Future<List<Movie>> getJKPopularTV({int page = 1}) async {
    return _fetchList('/api/tv/jk-popular', page: page);
  }

  static Future<List<Movie>> getPopularTV({int page = 1}) async {
    return _fetchList('/api/tv/popular', page: page);
  }

  static Future<Movie> getMovieDetails(int movieId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/movie/$movieId'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return Movie.fromJson(data['data']);
      }
    }
    throw Exception('Failed to load movie details: ${response.statusCode}');
  }

  static Future<Movie> getTVDetails(int tvId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tv/$tvId'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return Movie.fromJson(data['data']);
      }
    }
    throw Exception('Failed to load TV details: ${response.statusCode}');
  }

  static Future<List<Movie>> search(String query, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/search?query=${Uri.encodeComponent(query)}&page=$page'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return _parseMovieList(data['data']);
      }
    }
    throw Exception('Failed to search: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getMovieGenres() async {
    final response = await http.get(Uri.parse('$baseUrl/api/genres/movie'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw Exception('Failed to load genres: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getTVGenres() async {
    final response = await http.get(Uri.parse('$baseUrl/api/genres/tv'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw Exception('Failed to load genres: ${response.statusCode}');
  }

  static Future<List<Movie>> _fetchDiscoverMovie(Map<String, String> params, {int page = 1}) async {
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return _fetchList('/api/discover/movie?$query', page: page);
  }

  static Future<List<Movie>> _fetchDiscoverTV(Map<String, String> params, {int page = 1}) async {
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return _fetchList('/api/discover/tv?$query', page: page);
  }

  static Future<Map<String, dynamic>> getTVSeasonDetails(int tvId, int seasonNumber) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tv/$tvId/season/$seasonNumber'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return Map<String, dynamic>.from(data['data']);
      }
    }
    throw Exception('Failed to load season details: ${response.statusCode}');
  }

  static Future<VodSearchResult> searchVod(String title, {String? originalTitle}) async {
    final params = <String, String>{'title': title};
    if (originalTitle != null && originalTitle.isNotEmpty) {
      params['originalTitle'] = originalTitle;
    }
    final uri = Uri.parse('$baseUrl/api/vod/search').replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return VodSearchResult.fromJson(data['data']);
      }
    }
    throw Exception('VOD search failed: ${response.statusCode}');
  }

  static Future<VodSearchResult> getVodDetail(String site, int vodId) async {
    final uri = Uri.parse('$baseUrl/api/vod/detail')
        .replace(queryParameters: {'site': site, 'id': vodId.toString()});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return VodSearchResult.fromJson(data['data']);
      }
    }
    throw Exception('VOD detail failed: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getVodCategory(int typeId, {int page = 1}) async {
    final uri = Uri.parse('$baseUrl/api/vod/category')
        .replace(queryParameters: {'typeId': typeId.toString(), 'page': page.toString()});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw Exception('Category fetch failed: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> multiSearchVod(String keyword) async {
    final uri = Uri.parse('$baseUrl/api/vod/multi-search')
        .replace(queryParameters: {'keyword': keyword});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (_parseSuccess(data['success'])) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    throw Exception('VOD multi-search failed: ${response.statusCode}');
  }

  static Future<List<Movie>> discoverMoviesByGenre(int genreId, {int page = 1}) async {
    return _fetchDiscoverMovie({'with_genres': genreId.toString()}, page: page);
  }

  static Future<List<Movie>> discoverTVByGenre(int genreId, {int page = 1}) async {
    return _fetchDiscoverTV({'with_genres': genreId.toString()}, page: page);
  }
}
