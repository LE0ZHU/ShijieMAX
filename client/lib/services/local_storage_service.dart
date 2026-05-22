import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';
import '../models/vod_source.dart';
import '../models/chat_session.dart';

class LocalStorageService {
  static const _favKey = 'favorites';
  static const _historyKey = 'history';
  static const _vodCacheKey = 'vod_cache';
  static const _groqApiKeyKey = 'groq_api_key';
  static const _maxHistory = 50;
  static const _maxVodCache = 30;
  static const _vodCacheExpiry = Duration(hours: 24);

  // --- Groq API Key ---

  static Future<String?> getGroqApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_groqApiKeyKey);
  }

  static Future<void> setGroqApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groqApiKeyKey, key);
  }

  static Future<void> clearGroqApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_groqApiKeyKey);
  }

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

  // --- Chat Sessions ---

  static const _chatKey = 'chat_sessions';
  static const _maxChatSessions = 50;

  static Future<List<ChatSession>> getChatSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ChatSession?> getChatSession(String id) async {
    final sessions = await getChatSessions();
    return sessions.firstWhere((s) => s.id == id, orElse: () => ChatSession.create());
  }

  static Future<void> saveChatSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getChatSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    // Sort by updated time (newest first)
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    // Limit to max sessions
    if (sessions.length > _maxChatSessions) {
      sessions.removeRange(_maxChatSessions, sessions.length);
    }
    await prefs.setString(_chatKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  static Future<void> deleteChatSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getChatSessions();
    sessions.removeWhere((s) => s.id == id);
    await prefs.setString(_chatKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  static Future<void> clearAllChatSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatKey);
  }

  static Future<void> updateChatSessionTitle(String id, String title) async {
    final sessions = await getChatSessions();
    final index = sessions.indexWhere((s) => s.id == id);
    if (index >= 0) {
      sessions[index] = ChatSession(
        id: sessions[index].id,
        title: title,
        createdAt: sessions[index].createdAt,
        updatedAt: DateTime.now(),
        messages: sessions[index].messages,
      );
      await saveChatSession(sessions[index]);
    }
  }

  // --- Current AI Chat Session (for session persistence across panel close/open) ---

  static const _currentAiChatKey = 'current_ai_chat_session';

  static Future<ChatSession?> getCurrentAiChatSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentAiChatKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ChatSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCurrentAiChatSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAiChatKey, jsonEncode(session.toJson()));
  }

  static Future<void> clearCurrentAiChatSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentAiChatKey);
  }
}
