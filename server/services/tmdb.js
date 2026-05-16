require('dotenv').config();
const axios = require('axios');

const TMDB_BASE_URL = process.env.TMDB_BASE_URL || 'https://api.themoviedb.org/3';
const TMDB_API_KEY = process.env.TMDB_API_KEY;
const IMAGE_BASE_URL = 'https://image.tmdb.org/t/p';

if (!TMDB_API_KEY) {
  console.error('ERROR: TMDB_API_KEY is not set. Please check your .env file.');
}

console.log('TMDB Config:', {
  baseURL: TMDB_BASE_URL,
  apiKey: TMDB_API_KEY ? '已设置 (长度:' + TMDB_API_KEY.length + ')' : '未设置',
});

const tmdbClient = axios.create({
  baseURL: TMDB_BASE_URL,
  timeout: 60000,
  params: {
    api_key: TMDB_API_KEY,
    language: 'zh-CN',
  },
  headers: {
    'Host': 'api.themoviedb.org',
  },
});

// 添加请求拦截器用于调试
tmdbClient.interceptors.request.use(
  (config) => {
    console.log(`[TMDB Request] ${config.method?.toUpperCase()} ${config.url}`, config.params);
    return config;
  },
  (error) => {
    console.error('[TMDB Request Error]', error.message);
    return Promise.reject(error);
  }
);

// 添加响应拦截器用于调试
tmdbClient.interceptors.response.use(
  (response) => {
    console.log(`[TMDB Response] ${response.status} ${response.config.url}`);
    return response;
  },
  (error) => {
    if (error.response) {
      console.error('[TMDB Response Error]', {
        status: error.response.status,
        statusText: error.response.statusText,
        data: error.response.data,
        url: error.config?.url,
      });
    } else if (error.request) {
      console.error('[TMDB Network Error]', error.code, error.message);
    } else {
      console.error('[TMDB Error]', error.message);
    }
    return Promise.reject(error);
  }
);

function getImageUrl(path, size = 'w500') {
  if (!path) return null;
  return `${IMAGE_BASE_URL}/${size}${path}`;
}

async function getTrendingMovies(timeWindow = 'week', page = 1) {
  const res = await tmdbClient.get(`/trending/movie/${timeWindow}`, { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    originalTitle: item.original_title,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    genreIds: item.genre_ids,
    type: 'movie',
  }));
}

async function getTrendingTV(timeWindow = 'week', page = 1) {
  const res = await tmdbClient.get(`/trending/tv/${timeWindow}`, { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.name,
    originalTitle: item.original_name,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.first_air_date,
    genreIds: item.genre_ids,
    type: 'tv',
  }));
}

async function getMovieDetails(movieId) {
  const [detailRes, creditsRes] = await Promise.all([
    tmdbClient.get(`/movie/${movieId}`),
    tmdbClient.get(`/movie/${movieId}/credits`),
  ]);
  const data = detailRes.data;
  const cast = (creditsRes.data.cast || []).slice(0, 12).map((c) => ({
    name: c.name,
    character: c.character,
    profileUrl: getImageUrl(c.profile_path, 'w185'),
  }));
  return {
    id: data.id,
    title: data.title,
    originalTitle: data.original_title,
    overview: data.overview,
    posterUrl: getImageUrl(data.poster_path),
    backdropUrl: getImageUrl(data.backdrop_path, 'original'),
    rating: data.vote_average,
    releaseDate: data.release_date,
    runtime: data.runtime,
    genres: data.genres,
    tagline: data.tagline,
    status: data.status,
    homepage: data.homepage,
    cast,
    type: 'movie',
  };
}

async function getTVDetails(tvId) {
  const [detailRes, creditsRes] = await Promise.all([
    tmdbClient.get(`/tv/${tvId}`),
    tmdbClient.get(`/tv/${tvId}/credits`),
  ]);
  const data = detailRes.data;
  const cast = (creditsRes.data.cast || []).slice(0, 12).map((c) => ({
    name: c.name,
    character: c.character,
    profileUrl: getImageUrl(c.profile_path, 'w185'),
  }));
  return {
    id: data.id,
    title: data.name,
    originalTitle: data.original_name,
    overview: data.overview,
    posterUrl: getImageUrl(data.poster_path),
    backdropUrl: getImageUrl(data.backdrop_path, 'original'),
    rating: data.vote_average,
    releaseDate: data.first_air_date,
    episodeRunTime: data.episode_run_time,
    genres: data.genres,
    tagline: data.tagline,
    status: data.status,
    numberOfSeasons: data.number_of_seasons,
    numberOfEpisodes: data.number_of_episodes,
    cast,
    type: 'tv',
  };
}

async function searchMulti(query, page = 1) {
  const res = await tmdbClient.get('/search/multi', { params: { query, page } });
  return res.data.results
    .filter((item) => item.media_type === 'movie' || item.media_type === 'tv')
    .map((item) => ({
      id: item.id,
      mediaType: item.media_type,
      title: item.title || item.name,
      originalTitle: item.original_title || item.original_name,
      overview: item.overview,
      posterUrl: getImageUrl(item.poster_path),
      backdropUrl: getImageUrl(item.backdrop_path, 'original'),
      rating: item.vote_average,
      releaseDate: item.release_date || item.first_air_date,
      type: item.media_type,
    }));
}

async function getMovieGenres() {
  const res = await tmdbClient.get('/genre/movie/list');
  return res.data.genres;
}

async function getTVGenres() {
  const res = await tmdbClient.get('/genre/tv/list');
  return res.data.genres;
}

async function discoverMovies(params = {}) {
  const res = await tmdbClient.get('/discover/movie', { params });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    type: 'movie',
  }));
}

async function discoverTV(params = {}) {
  const res = await tmdbClient.get('/discover/tv', { params });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.name,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.first_air_date,
    type: 'tv',
  }));
}

async function getNowPlayingMovies(page = 1) {
  const res = await tmdbClient.get('/movie/now_playing', { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    originalTitle: item.original_title,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    genreIds: item.genre_ids,
    type: 'movie',
  }));
}

async function getUpcomingMovies(page = 1) {
  const res = await tmdbClient.get('/movie/upcoming', { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    originalTitle: item.original_title,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    genreIds: item.genre_ids,
    type: 'movie',
  }));
}

async function getTopRatedMovies(page = 1) {
  const res = await tmdbClient.get('/movie/top_rated', { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    originalTitle: item.original_title,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    genreIds: item.genre_ids,
    type: 'movie',
  }));
}

async function getTopRatedTV(page = 1) {
  const res = await tmdbClient.get('/tv/top_rated', { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.name,
    originalTitle: item.original_name,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.first_air_date,
    genreIds: item.genre_ids,
    type: 'tv',
  }));
}

async function getPopularMovies(page = 1) {
  const res = await tmdbClient.get('/movie/popular', { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    originalTitle: item.original_title,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    genreIds: item.genre_ids,
    type: 'movie',
  }));
}

async function getChinesePopularMovies(page = 1) {
  const res = await tmdbClient.get('/discover/movie', {
    params: {
      page,
      with_original_language: 'zh',
      sort_by: 'popularity.desc',
      'vote_count.gte': 50,
    },
  });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.title,
    originalTitle: item.original_title,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.release_date,
    genreIds: item.genre_ids,
    type: 'movie',
  }));
}

async function getChinesePopularTV(page = 1) {
  const res = await tmdbClient.get('/discover/tv', {
    params: {
      page,
      with_original_language: 'zh',
      sort_by: 'popularity.desc',
      'vote_count.gte': 50,
    },
  });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.name,
    originalTitle: item.original_name,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.first_air_date,
    genreIds: item.genre_ids,
    type: 'tv',
  }));
}

async function getJKPopularTV(page = 1) {
  const res = await tmdbClient.get('/discover/tv', {
    params: {
      page,
      with_origin_country: 'JP|KR',
      sort_by: 'popularity.desc',
      'vote_count.gte': 50,
    },
  });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.name,
    originalTitle: item.original_name,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.first_air_date,
    genreIds: item.genre_ids,
    type: 'tv',
  }));
}

async function getPopularTV(page = 1) {
  const res = await tmdbClient.get('/tv/popular', { params: { page } });
  return res.data.results.map((item) => ({
    id: item.id,
    title: item.name,
    originalTitle: item.original_name,
    overview: item.overview,
    posterUrl: getImageUrl(item.poster_path),
    backdropUrl: getImageUrl(item.backdrop_path, 'original'),
    rating: item.vote_average,
    releaseDate: item.first_air_date,
    genreIds: item.genre_ids,
    type: 'tv',
  }));
}

async function getTVSeasonDetails(tvId, seasonNumber) {
  const res = await tmdbClient.get(`/tv/${tvId}/season/${seasonNumber}`);
  const data = res.data;
  return {
    id: data.id,
    seasonNumber: data.season_number,
    name: data.name,
    overview: data.overview,
    posterUrl: getImageUrl(data.poster_path),
    airDate: data.air_date,
    episodes: (data.episodes || []).map((ep) => ({
      id: ep.id,
      episodeNumber: ep.episode_number,
      name: ep.name,
      overview: ep.overview,
      stillUrl: getImageUrl(ep.still_path),
      airDate: ep.air_date,
      runtime: ep.runtime,
      voteAverage: ep.vote_average,
    })),
  };
}

module.exports = {
  getTrendingMovies,
  getTrendingTV,
  getMovieDetails,
  getTVDetails,
  searchMulti,
  getMovieGenres,
  getTVGenres,
  discoverMovies,
  discoverTV,
  getNowPlayingMovies,
  getUpcomingMovies,
  getTopRatedMovies,
  getTopRatedTV,
  getPopularMovies,
  getPopularTV,
  getChinesePopularTV,
  getChinesePopularMovies,
  getJKPopularTV,
  getTVSeasonDetails,
};
