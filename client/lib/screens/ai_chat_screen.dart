import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../models/chat_session.dart';
import '../services/ai_chat_service.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'player_screen.dart';
import 'search_screen.dart';

class AiChatScreen extends StatefulWidget {
  final ChatSession? initialSession;

  const AiChatScreen({super.key, this.initialSession});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiChatService _aiService = AiChatService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  StreamSubscription<String>? _streamSubscription;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    if (widget.initialSession != null) {
      _sessionId = widget.initialSession!.id;
      _messages = List.from(widget.initialSession!.messages);
    } else {
      // 尝试加载上次未完成的会话
      final savedSession = await LocalStorageService.getCurrentAiChatSession();
      if (savedSession != null && savedSession.messages.isNotEmpty) {
        _sessionId = savedSession.id;
        _messages = List.from(savedSession.messages);
      }
    }
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    // 如果正在加载，标记最后一条消息为中断
    if (_isLoading && _messages.isNotEmpty) {
      _messages.last.wasInterrupted = true;
    }
    _saveCurrentSession();
    _streamSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentSession() async {
    if (_messages.isEmpty) {
      await LocalStorageService.clearCurrentAiChatSession();
      return;
    }

    final now = DateTime.now();
    String title = '新对话 ${_formatTime(now)}';

    final firstUserMsg = _messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => _messages.first,
    );
    if (firstUserMsg.content.isNotEmpty) {
      title = firstUserMsg.content.length > 20
          ? '${firstUserMsg.content.substring(0, 20)}...'
          : firstUserMsg.content;
    }

    final session = ChatSession(
      id: _sessionId ?? 'chat_${now.microsecondsSinceEpoch}',
      title: title,
      createdAt: _sessionId == null ? now : DateTime.now(),
      updatedAt: now,
      messages: List.from(_messages),
    );

    await LocalStorageService.saveCurrentAiChatSession(session);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveSession() async {
    if (_messages.isEmpty) return;

    final now = DateTime.now();
    String title = '新对话 ${_formatTime(now)}';

    // 尝试从第一条用户消息生成标题
    final firstUserMsg = _messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => _messages.first,
    );
    if (firstUserMsg.content.isNotEmpty) {
      title = firstUserMsg.content.length > 20
          ? '${firstUserMsg.content.substring(0, 20)}...'
          : firstUserMsg.content;
    }

    final session = ChatSession(
      id: _sessionId ?? 'chat_${now.microsecondsSinceEpoch}',
      title: title,
      createdAt: _sessionId == null ? now : DateTime.now(),
      updatedAt: now,
      messages: List.from(_messages),
    );

    await LocalStorageService.saveChatSession(session);
    _sessionId = session.id;
  }

  String _formatTime(DateTime time) {
    return '${time.month}月${time.day}日 ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _retryLastMessage() async {
    // 找到最后一条被中断的 assistant 消息，删除它，重新发送对应的用户消息
    if (_messages.isEmpty) return;

    // 找到最后一条被中断的 assistant 消息的索引
    int interruptedIdx = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].wasInterrupted) {
        interruptedIdx = i;
        break;
      }
    }
    if (interruptedIdx < 0) return;

    // 找到对应的用户消息（中断消息之前的最后一条用户消息）
    String? userText;
    for (int i = interruptedIdx - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        userText = _messages[i].content;
        break;
      }
    }
    if (userText == null) return;

    // 删除被中断的 assistant 消息及之后的所有消息
    setState(() {
      _messages.removeRange(interruptedIdx, _messages.length);
    });

    // 重新发送
    _inputController.text = userText;
    _sendMessage();
  }

  Future<String?> _buildWatchHistoryContext() async {
    try {
      final historyList = await LocalStorageService.getHistory();
      if (historyList.isEmpty) return null;

      final recentItems = historyList.take(10).toList();
      final lines = recentItems.map((item) {
        final title = item['title'] ?? '';
        final type = item['type'] ?? '';
        final typeLabel = type == 'tv' ? '剧集' : '电影';
        return '- $title（$typeLabel）';
      }).toList();

      return lines.join('\n');
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messages.add(ChatMessage(role: 'assistant', content: ''));
      _isLoading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    // 先检查是否是明确的搜索请求，尝试直接提取电影名
    final directSearchNames = _extractDirectSearchNames(text);

    try {
      final history = _messages
          .where((m) => !m.isSearching && m.content.isNotEmpty)
          .take(_messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // 获取观看历史作为上下文
      final watchHistory = await _buildWatchHistoryContext();

      _streamSubscription = _aiService.sendMessageStream(history, watchHistory: watchHistory).listen(
        (chunk) {
          setState(() {
            _messages.last.content += chunk;
          });
          _scrollToBottom();
        },
        onDone: () async {
          if (!mounted) return;
          final fullResponse = _messages.last.content;
          setState(() {
            _isLoading = false;
          });

          await _saveSession();
          await _saveCurrentSession();

          var recommendations = AiChatService.parseRecommendations(fullResponse, text);
          
          // 如果 AI 没有提取到，但我们直接提取到了，使用直接提取的
          if (recommendations.isEmpty && directSearchNames.isNotEmpty) {
            recommendations = directSearchNames;
          }
          
          if (recommendations.isNotEmpty) {
            await _searchRecommendations(recommendations);
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _messages.removeLast();
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _isLoading = false;
      });
    }
  }

  List<String> _extractDirectSearchNames(String text) {
    final searchPatterns = [
      RegExp(r'(?:搜索|搜)\s*[《"]?([^《》"\s,，。.]{2,50})[》"]?'),
      RegExp(r'(?:想看|找)\s+[《"]?([^《》"\s,，。.]{2,50})[》"]?'),
      RegExp(r'[《"]([^《》"]{2,50})[》"]\s*(?:怎么看|哪里看|搜一下|搜索一下)'),
    ];
    
    final stopWords = {'一下', '一个', '一部', '一些', '什么', '哪些', '几部', '一下下', '一点'};
    
    for (final pattern in searchPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final name = match.group(1)!.trim();
        if (name.length >= 2 && !stopWords.contains(name)) {
          return [name];
        }
      }
    }
    
    return [];
  }

  Future<void> _searchRecommendations(List<String> titles) async {
    setState(() {
      _messages.add(ChatMessage(
        role: 'assistant',
        content: '正在搜索 "${titles.join("、")}"...',
        isSearching: true,
      ));
    });
    _scrollToBottom();

    final allResults = <Map<String, dynamic>>[];

    for (final title in titles) {
      try {
        final results = await ApiService.multiSearchVod(title.trim());
        if (results.isNotEmpty) {
          final filteredResults = results.take(3).map((r) => Map<String, dynamic>.from(r)).toList();
          allResults.add({
            'title': title,
            'results': filteredResults,
          });
        }
      } catch (e) {
        // 忽略搜索错误
      }
    }

    if (!mounted) return;

    setState(() {
      final idx = _messages.lastIndexWhere((m) => m.isSearching && m.content.contains('正在搜索'));
      if (idx >= 0) {
        _messages[idx] = ChatMessage(
          role: 'assistant',
          content: allResults.isEmpty ? '未找到相关资源' : '找到以下资源：',
          isSearching: false,
          searchResults: List.from(allResults),
        );
      }
    });

    await _saveSession();
    await _saveCurrentSession();
    _scrollToBottom();
  }

  Future<void> _onResultTap(Map<String, dynamic> vodItem) async {
    final vodId = int.tryParse(vodItem['vodId']?.toString() ?? '');
    final siteKey = vodItem['siteKey']?.toString() ?? '';
    if (vodId == null || siteKey.isEmpty) return;

    try {
      final result = await ApiService.getVodDetail(siteKey, vodId);
      if (!mounted) return;

      if (!result.found || result.sources.isEmpty) {
        _showSnack('未找到可播放资源');
        return;
      }

      final movie = Movie(
        id: vodId,
        title: result.title ?? vodItem['name'] ?? '',
        originalTitle: null,
        overview: result.description,
        posterUrl: result.poster,
        backdropUrl: null,
        rating: 0,
        releaseDate: result.year ?? '',
        type: (vodItem['typeName'] ?? '').toString().contains('剧') ? 'tv' : 'movie',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(movie: movie),
        ),
      );
    } catch (e) {
      _showSnack('加载失败');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE50914)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.6),
              elevation: 0,
              shadowColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 影伴',
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'DeepSeek · 智能推荐',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                if (_messages.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface.withOpacity(0.5), size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
                          title: Text('清空对话', style: TextStyle(color: theme.colorScheme.onSurface)),
                          content: Text('确定要清空所有聊天记录吗？', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _messages.clear();
                                  _sessionId = null;
                                });
                                LocalStorageService.clearCurrentAiChatSession();
                              },
                              child: const Text('清空', style: TextStyle(color: Color(0xFFE50914))),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildMessageList(),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMoodBar(isDark, theme),
                _buildInputBar(isDark, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return _buildEmptyHint();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, kToolbarHeight + MediaQuery.of(context).padding.top + 16, 16, kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom + 120),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  Widget _buildEmptyHint() {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'AI 找片',
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '描述你想看的电影或剧集\nAI 帮你智能推荐并自动搜索播放源',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _quickChip('漫威超级英雄'),
                  _quickChip('宫崎骏动画'),
                  _quickChip('悬疑烧脑'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodBar(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _moodChip('✨', '猜我喜欢', '根据我的观看记录推荐我可能喜欢的影片'),
            const SizedBox(width: 8),
            _moodChip('😊', '开心', '推荐适合开心时看的轻松欢乐影片'),
            const SizedBox(width: 8),
            _moodChip('😔', 'emo', '推荐适合emo时看的走心深刻影片'),
            const SizedBox(width: 8),
            _moodChip('😢', '想哭', '推荐催泪感人的影片让我好好哭一场'),
            const SizedBox(width: 8),
            _moodChip('🧸', '治愈', '推荐温暖治愈的影片让我心情好起来'),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        _inputController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
        ),
        child: Text(text, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
      ),
    );
  }

  Widget _moodChip(String emoji, String label, String prompt) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        _inputController.text = prompt;
        _sendMessage();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = msg.role == 'user';

    // 安全检查搜索结果
    final hasValidSearchResults = msg.searchResults != null && 
        msg.searchResults!.isNotEmpty && 
        msg.searchResults!.every((group) => 
          group.containsKey('title') && 
          group.containsKey('results') && 
          group['results'] is List && 
          (group['results'] as List).isNotEmpty
        );

    if (hasValidSearchResults) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAiBubble(msg.content, isDark, theme),
          const SizedBox(height: 12),
          ...msg.searchResults!.expand((group) {
            final queryTitle = group['title'] as String;
            final rawResults = group['results'];
            if (rawResults is! List) return <Widget>[];
            
            final results = rawResults.whereType<Map<String, dynamic>>().toList();
            if (results.isEmpty) return <Widget>[];
            
            return [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.movie_filter, color: Color(0xFFE50914), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '关于 "$queryTitle"',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SearchScreen(initialQuery: queryTitle),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '去搜索',
                            style: TextStyle(
                              color: const Color(0xFFE50914),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: const Color(0xFFE50914),
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ...results.map((r) => _buildResultCard(r, isDark, theme)),
            ];
          }),
          const SizedBox(height: 16),
        ],
      );
    }

    if (msg.isSearching) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAiBubble(msg.content, isDark, theme),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          _buildAiBubble(msg.content, isDark, theme),
          if (msg.wasInterrupted) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isLoading ? null : _retryLastMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE50914).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: const Color(0xFFE50914), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '回答被中断，点击重新回答',
                      style: TextStyle(color: const Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ] else ...[
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAiBubble(String content, bool isDark, ThemeData theme) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        content,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item, bool isDark, ThemeData theme) {
    final name = item['name']?.toString() ?? '';
    final typeName = item['typeName']?.toString() ?? '';
    final remark = item['remark']?.toString() ?? '';
    final poster = item['pic']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _onResultTap(item),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'movie_poster_${item['vodId'] ?? name}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 50,
                    height: 68,
                    child: poster != null && poster.isNotEmpty
                        ? CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.grey.shade800))
                        : Container(color: Colors.grey.shade800, child: const Icon(Icons.movie, color: Colors.white54, size: 24)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (typeName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(typeName, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 12)),
                    ],
                    if (remark.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(remark, style: const TextStyle(color: Color(0xFFE50914), fontSize: 11)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.play_circle_outline, color: theme.colorScheme.onSurface.withOpacity(0.3), size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark, ThemeData theme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.6),
            border: Border(
              top: BorderSide(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.08), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: _inputController,
                    enabled: !_isLoading,
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '描述你想看的电影或剧集...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _isLoading
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: _isLoading ? Colors.grey.shade700 : null,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
        ],
      ),
      ),
    ),
    );
}
}