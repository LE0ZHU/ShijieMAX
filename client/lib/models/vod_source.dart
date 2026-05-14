class VodEpisode {
  final String name;
  final String url;
  final bool isM3u8;

  VodEpisode({required this.name, required this.url, required this.isM3u8});

  factory VodEpisode.fromJson(Map<String, dynamic> json) => VodEpisode(
        name: json['name'] ?? '',
        url: json['url'] ?? '',
        isM3u8: json['isM3u8'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'isM3u8': isM3u8,
      };
}

class VodSource {
  final String sourceName;
  final List<VodEpisode> episodes;
  final bool hasM3u8;

  VodSource({required this.sourceName, required this.episodes, required this.hasM3u8});

  factory VodSource.fromJson(Map<String, dynamic> json) => VodSource(
        sourceName: json['sourceName'] ?? '',
        episodes: (json['episodes'] as List?)
                ?.map((e) => VodEpisode.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        hasM3u8: json['hasM3u8'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'sourceName': sourceName,
        'hasM3u8': hasM3u8,
        'episodes': episodes.map((e) => e.toJson()).toList(),
      };

  VodEpisode? get firstM3u8Episode {
    for (final ep in episodes) {
      if (ep.isM3u8) return ep;
    }
    return null;
  }
}

class VodSearchResult {
  final bool found;
  final String? title;
  final String? poster;
  final String? typeName;
  final String? remark;
  final String? year;
  final String? area;
  final String? lang;
  final String? actor;
  final String? director;
  final String? description;
  final List<VodSource> sources;

  VodSearchResult({
    required this.found,
    this.title,
    this.poster,
    this.typeName,
    this.remark,
    this.year,
    this.area,
    this.lang,
    this.actor,
    this.director,
    this.description,
    required this.sources,
  });

  factory VodSearchResult.fromJson(Map<String, dynamic> json) => VodSearchResult(
        found: json['found'] ?? false,
        title: json['name']?.toString(),
        poster: json['pic']?.toString(),
        typeName: json['typeName']?.toString(),
        remark: json['remark']?.toString(),
        year: json['year']?.toString(),
        area: json['area']?.toString(),
        lang: json['lang']?.toString(),
        actor: json['actor']?.toString(),
        director: json['director']?.toString(),
        description: json['description']?.toString(),
        sources: (json['sources'] as List?)
                ?.map((e) => VodSource.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String? get firstPlayableUrl {
    for (final source in sources) {
      for (final ep in source.episodes) {
        if (ep.isM3u8) return ep.url;
      }
    }
    for (final source in sources) {
      for (final ep in source.episodes) {
        if (ep.url.isNotEmpty) return ep.url;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'found': found,
        'name': title,
        'pic': poster,
        'typeName': typeName,
        'remark': remark,
        'year': year,
        'area': area,
        'lang': lang,
        'actor': actor,
        'director': director,
        'description': description,
        'sources': sources.map((s) => s.toJson()).toList(),
      };

  List<VodSource> get m3u8Sources => sources.where((s) => s.hasM3u8).toList();
}
