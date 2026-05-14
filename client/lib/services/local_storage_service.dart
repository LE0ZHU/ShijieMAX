import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';

class LocalStorageService {
  static const _favKey = 'favorites';
  static const _historyKey = 'history';
  static const _vodCacheKey = 'vod_cache';
  static const _maxHistory = 50;
  static const _maxVodCache = 30;
  static const _vodCacheExpiry = Duration(hours: 24);

  // --- Favorites ---

  static Future<List<Movie>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Movie.fromJson(e)).toList();
  }

  static Future<bool> isFavorite(int movieId) async {
    final favs = await getFavorites();
    return favs.any((m) => m.id == movieId);
  }

  static Future<void> toggleFavorite(Movie movie) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavorites();
    final idx = favs.indexWhere((m) => m.id == movie.id);
    if (idx >= 0) {
      favs.removeAt(idx);
    } else {
      favs.insert(0, movie);
    }
    final raw = jsonEncode(favs.map((m) => m.toJson()).toList());
    await prefs.setString(_favKey, raw);
  }

  static Future<void> removeFavorite(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavorites();
    favs.removeWhere((m) => m.id == movieId);
    await prefs.setString(_favKey, jsonEncode(favs.map((m) => m.toJson()).toList()));
  }

  static Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favKey);
  }

  // --- Watch History ---

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<Map<String, dynamic>?> getHistoryForMovie(int movieId) async {
    final history = await getHistory();
    for (final h in history) {
      if (h['id'] == movieId) return h;
    }
    return null;
  }

  static Future<void> addToHistory({
    required Movie movie,
    int episodeIndex = 0,
    String? episodeName,
    String? sourceName,
    double position = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere((h) => h['id'] == movie.id);
    history.insert(0, {
      ...movie.toJson(),
      'watchedAt': DateTime.now().toIso8601String(),
      'episodeIndex': episodeIndex,
      'episodeName': episodeName ?? '',
      'sourceName': sourceName ?? '',
      'position': position,
    });
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  static Future<void> updateHistoryPosition({
    required int movieId,
    int? episodeIndex,
    String? episodeName,
    double position = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    for (final h in history) {
      if (h['id'] == movieId) {
        h['watchedAt'] = DateTime.now().toIso8601String();
        h['position'] = position;
        if (episodeIndex != null) h['episodeIndex'] = episodeIndex;
        if (episodeName != null) h['episodeName'] = episodeName;
        await prefs.setString(_historyKey, jsonEncode(history));
        return;
      }
    }
  }

  static Future<void> removeFromHistory(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere((h) => h['id'] == movieId);
    await prefs.setString(_historyKey, jsonEncode(history));
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // --- VOD Cache ---

  static Future<Map<String, dynamic>?> getCachedVod(int movieId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vodCacheKey);
    if (raw == null) return null;
    final list = List<Map<String, dynamic>>.from(jsonDecode(raw));
    for (final entry in list) {
      if (entry['id'] == movieId) {
        final cachedAt = DateTime.tryParse(entry['cachedAt'] ?? '');
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt) < _vodCacheExpiry) {
          return entry['data'];
        }
        return null; // Expired
      }
    }
    return null;
  }

  static Future<void> cacheVodResult(int movieId, VodSearchResult result) async {
    if (!result.found || result.sources.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vodCacheKey);
    final list = raw != null
        ? List<Map<String, dynamic>>.from(jsonDecode(raw))
        : <Map<String, dynamic>>[];
    list.removeWhere((e) => e['id'] == movieId);
    list.insert(0, {
      'id': movieId,
      'cachedAt': DateTime.now().toIso8601String(),
      'data': result.toJson(),
    });
    if (list.length > _maxVodCache) {
      list.removeRange(_maxVodCache, list.length);
    }
    await prefs.setString(_vodCacheKey, jsonEncode(list));
  }
}
