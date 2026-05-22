import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiChatService {
  static const String _baseUrl = 'https://api.deepseek.com';
  static const String _model = 'deepseek-v4-flash';
  static const String _apiKey = 'sk-a4e31d7fe6c44b0f9d36ac5e7bcdaacf';

  static String _buildSystemPrompt({String? watchHistory}) {
    String prompt = '''你是一个专业的影视推荐助手，名字叫"视界AI"。

规则：
1. 当用户描述想看的电影类型、风格、请求推荐或搜索影片时，**必须**推荐 1-3 个影片，**必须**用书名号《》括起来
2. 当用户问某部具体影片的剧情、介绍、导演、演员等信息时，直接回答，不需要重复推荐该片，只讲信息即可
3. 用自然、友好的中文回复''';

    if (watchHistory != null && watchHistory.isNotEmpty) {
      prompt += '''

4. 用户的观看历史如下，请结合用户的观看偏好进行个性化推荐：
$watchHistory
当用户请求推荐但没有明确方向时，优先根据观看历史推测用户喜好，推荐风格或类型相近的影片。''';
    }

    prompt += '''

示例：
用户输入：我想看类似盗梦空间的科幻片
回复：诺兰的科幻片都很适合！推荐《星际穿越》、《黑客帝国》、《源代码》。

用户输入：帮我搜一下复仇者联盟
回复：好的！帮你找到《复仇者联盟》。

用户输入：肖申克的救赎讲了什么故事
回复：影片讲述银行家安迪被冤枉入狱，在肖申克监狱中与瑞德成为好友，用二十年时间策划越狱，最终重获自由的故事。''';

    return prompt;
  }

  Stream<String> sendMessageStream(List<Map<String, String>> messages, {String? watchHistory}) async* {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _buildSystemPrompt(watchHistory: watchHistory)},
        ...messages,
      ],
      'stream': true,
    });

    final request = http.Request('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      'Content-Type': 'application/json',
    });
    request.body = body;

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        final error = jsonDecode(responseBody);
        throw Exception(error['error']?['message'] ?? 'AI 请求失败: ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') break;
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'] ?? '';
              if (content.isNotEmpty) {
                yield content;
              }
            } catch (_) {}
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<String> sendMessage(List<Map<String, String>> messages) async {
    final buffer = StringBuffer();
    await for (final chunk in sendMessageStream(messages)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  static List<String> parseRecommendations(String aiResponse, String userPrompt) {
    final isRecommendationRequest = userPrompt.contains(RegExp(r'推荐|想看|类似|有什么好|好看的|推荐点|找片|介绍|给我|帮我找|找一下|有哪些|推荐几部|求推荐|搜|搜索|找|超级英雄|电影|电视剧|剧集|影视|动漫|剧|片'));
    if (!isRecommendationRequest) return [];

    final regex = RegExp(r'《([^《》]+)》');
    final matches = regex.allMatches(aiResponse);
    final results = matches
        .map((m) => m.group(1)?.trim() ?? '')
        .where((e) => e.isNotEmpty && e.length > 1)
        .toList();
    return results.take(3).toList();
  }
}