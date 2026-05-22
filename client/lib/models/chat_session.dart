import 'dart:convert';

/// 对话消息
class ChatMessage {
  final String role;
  String content;
  final bool isSearching;
  final List<Map<String, dynamic>>? searchResults;
  bool wasInterrupted;

  ChatMessage({
    required this.role,
    required this.content,
    this.isSearching = false,
    this.searchResults,
    this.wasInterrupted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'isSearching': isSearching,
      'wasInterrupted': wasInterrupted,
      'searchResults': searchResults?.map((group) {
        return {
          'title': group['title'],
          'results': (group['results'] as List).map((item) => Map<String, dynamic>.from(item)).toList(),
        };
      }).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // 安全处理 searchResults
    List<Map<String, dynamic>>? searchResults;
    final rawSearchResults = json['searchResults'];
    if (rawSearchResults != null && rawSearchResults is List) {
      searchResults = rawSearchResults.map((item) {
        if (item is Map<String, dynamic>) {
          final title = item['title'] as String?;
          final rawResults = item['results'];
          if (rawResults is List) {
            final results = rawResults
                .map((r) {
                  if (r is Map<String, dynamic>) {
                    return r;
                  } else if (r is Map) {
                    return Map<String, dynamic>.from(r);
                  }
                  return null;
                })
                .whereType<Map<String, dynamic>>()
                .toList();
            if (title != null) {
              return {'title': title, 'results': results};
            }
          }
        }
        return null;
      })
          .whereType<Map<String, dynamic>>()
          .toList();
    }

    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      isSearching: json['isSearching'] as bool? ?? false,
      wasInterrupted: json['wasInterrupted'] as bool? ?? false,
      searchResults: searchResults,
    );
  }
}

/// 对话会话
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 生成预览摘要（取第一条用户消息或标题）
  String get preview {
    if (messages.isEmpty) return '空对话';
    final firstUserMsg = messages.firstWhere((m) => m.role == 'user', orElse: () => messages.first);
    return firstUserMsg.content.length > 30
        ? '${firstUserMsg.content.substring(0, 30)}...'
        : firstUserMsg.content;
  }

  /// 创建新的空会话
  static ChatSession create() {
    final now = DateTime.now();
    return ChatSession(
      id: _generateId(),
      title: '新对话 ${_formatTime(now)}',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
  }

  /// 生成唯一ID
  static String _generateId() {
    final now = DateTime.now();
    return 'chat_${now.microsecondsSinceEpoch}';
  }

  /// 格式化时间
  static String _formatTime(DateTime time) {
    return '${time.month}月${time.day}日 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// 对话存储服务
class ChatStorageService {
  static const String _key = 'chat_sessions';
  static const int _maxSessions = 50;

  /// 保存会话列表
  static Future<void> saveSessions(List<ChatSession> sessions) async {
    final prefs = await _getPrefs();
    // 按更新时间排序，保留最近的
    final sorted = sessions
        .where((s) => s.messages.isNotEmpty)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final limited = sorted.take(_maxSessions).toList();
    final json = jsonEncode(limited.map((s) => s.toJson()).toList());
    await prefs.setString(_key, json);
  }

  /// 获取所有会话
  static Future<List<ChatSession>> getSessions() async {
    final prefs = await _getPrefs();
    final json = prefs.getString(_key);
    if (json == null || json.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(json);
      return list.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取单个会话
  static Future<ChatSession?> getSession(String id) async {
    final sessions = await getSessions();
    return sessions.firstWhere((s) => s.id == id, orElse: () => ChatSession.create());
  }

  /// 保存单个会话
  static Future<void> saveSession(ChatSession session) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    await saveSessions(sessions);
  }

  /// 删除会话
  static Future<void> deleteSession(String id) async {
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == id);
    await saveSessions(sessions);
  }

  /// 清空所有会话
  static Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_key);
  }

  /// 更新会话标题
  static Future<void> updateSessionTitle(String id, String title) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == id);
    if (index >= 0) {
      sessions[index] = ChatSession(
        id: sessions[index].id,
        title: title,
        createdAt: sessions[index].createdAt,
        updatedAt: DateTime.now(),
        messages: sessions[index].messages,
      );
      await saveSessions(sessions);
    }
  }

  /// 获取共享偏好设置
  static Future<dynamic> _getPrefs() async {
    // 这里会在 LocalStorageService 中实现
    throw UnimplementedError();
  }
}
