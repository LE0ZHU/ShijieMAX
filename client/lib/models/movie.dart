class Movie {
  final int id;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final double rating;
  final String? releaseDate;
  final List<int>? genreIds;
  final List<Map<String, dynamic>>? genres;
  final int? runtime;
  final String? tagline;
  final String? status;
  final String? homepage;
  final String type;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<Map<String, dynamic>>? cast;

  Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    required this.rating,
    this.releaseDate,
    this.genreIds,
    this.genres,
    this.runtime,
    this.tagline,
    this.status,
    this.homepage,
    this.type = 'movie',
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.cast,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: (json['id'] ?? 0) as int,
      title: (json['title'] ?? json['name'] ?? '未知标题').toString(),
      originalTitle: json['originalTitle']?.toString() ?? json['original_title']?.toString(),
      overview: json['overview']?.toString(),
      posterUrl: json['posterUrl']?.toString() ?? (json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : null),
      backdropUrl: json['backdropUrl']?.toString() ?? (json['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/original${json['backdrop_path']}'
          : null),
      rating: ((json['rating'] ?? json['vote_average'] ?? 0) as num).toDouble(),
      releaseDate: json['releaseDate']?.toString() ?? json['release_date']?.toString() ?? json['first_air_date']?.toString(),
      genreIds: _parseGenreIds(json['genreIds'] ?? json['genre_ids']),
      genres: _parseGenres(json['genres']),
      runtime: json['runtime'] != null ? (json['runtime'] as num).toInt() : null,
      tagline: json['tagline']?.toString(),
      status: json['status']?.toString(),
      homepage: json['homepage']?.toString(),
      type: json['type']?.toString() ?? json['mediaType']?.toString() ?? 'movie',
      numberOfSeasons: json['numberOfSeasons'] != null ? (json['numberOfSeasons'] as num).toInt() : null,
      numberOfEpisodes: json['numberOfEpisodes'] != null ? (json['numberOfEpisodes'] as num).toInt() : null,
      cast: json['cast'] is List ? List<Map<String, dynamic>>.from(json['cast']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'originalTitle': originalTitle,
      'overview': overview,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'rating': rating,
      'releaseDate': releaseDate,
      'genreIds': genreIds,
      'genres': genres,
      'runtime': runtime,
      'tagline': tagline,
      'status': status,
      'homepage': homepage,
      'type': type,
      'numberOfSeasons': numberOfSeasons,
      'numberOfEpisodes': numberOfEpisodes,
      'cast': cast,
    };
  }

  static List<int>? _parseGenreIds(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => (e as num).toInt()).toList();
    }
    return null;
  }

  static List<Map<String, dynamic>>? _parseGenres(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return null;
  }
}
