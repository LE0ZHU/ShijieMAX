require('dotenv').config();
const express = require('express');
const cors = require('cors');
const tmdb = require('./services/tmdb');
const vod = require('./services/vod');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: '视界TV 服务端运行中', status: 'ok' });
});

app.get('/api/trending/movies', async (req, res) => {
  try {
    const { timeWindow = 'week', page = 1 } = req.query;
    const data = await tmdb.getTrendingMovies(timeWindow, Number(page));
    res.json({ success: true, data });
  } catch (error) {
    console.error('TMDB Error:', error.response?.data || error.message);
    res.status(500).json({ success: false, message: error.response?.data?.status_message || error.message });
  }
});

app.get('/api/trending/tv', async (req, res) => {
  try {
    const { timeWindow = 'week', page = 1 } = req.query;
    const data = await tmdb.getTrendingTV(timeWindow, Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/search', async (req, res) => {
  try {
    const { query, page = 1 } = req.query;
    if (!query) {
      return res.status(400).json({ success: false, message: '缺少 query 参数' });
    }
    const data = await tmdb.searchMulti(query, Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/genres/movie', async (req, res) => {
  try {
    const data = await tmdb.getMovieGenres();
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/genres/tv', async (req, res) => {
  try {
    const data = await tmdb.getTVGenres();
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/discover/movie', async (req, res) => {
  try {
    const data = await tmdb.discoverMovies(req.query);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/discover/tv', async (req, res) => {
  try {
    const data = await tmdb.discoverTV(req.query);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/movies/now-playing', async (req, res) => {
  try {
    const { page = 1 } = req.query;
    const data = await tmdb.getNowPlayingMovies(Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/movies/upcoming', async (req, res) => {
  try {
    const { page = 1 } = req.query;
    const data = await tmdb.getUpcomingMovies(Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/movies/top-rated', async (req, res) => {
  try {
    const { page = 1 } = req.query;
    const data = await tmdb.getTopRatedMovies(Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/movies/popular', async (req, res) => {
  try {
    const { page = 1 } = req.query;
    const data = await tmdb.getPopularMovies(Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/tv/top_rated', async (req, res) => {
  try {
    const { page = 1 } = req.query;
    const data = await tmdb.getTopRatedTV(Number(page));
    res.json({ success: true, data });
  } catch (error) {
    console.error('/api/tv/top_rated Error:', error.response?.data || error.message);
    res.status(500).json({ success: false, message: error.response?.data?.status_message || error.message });
  }
});

app.get('/api/tv/popular', async (req, res) => {
  try {
    const { page = 1 } = req.query;
    const data = await tmdb.getPopularTV(Number(page));
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/movie/:id', async (req, res) => {
  try {
    const data = await tmdb.getMovieDetails(req.params.id);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/tv/:id/season/:seasonNumber', async (req, res) => {
  try {
    const data = await tmdb.getTVSeasonDetails(req.params.id, req.params.seasonNumber);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/tv/:id', async (req, res) => {
  try {
    const data = await tmdb.getTVDetails(req.params.id);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/vod/search', async (req, res) => {
  try {
    const { title, originalTitle } = req.query;
    if (!title) {
      return res.status(400).json({ success: false, message: '缺少 title 参数' });
    }
    const result = await vod.searchAndResolve(title, originalTitle || '');
    res.json({ success: true, data: result });
  } catch (error) {
    console.error('[VOD] Search error:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/vod/detail', async (req, res) => {
  try {
    const { site, id } = req.query;
    if (!site || !id) {
      return res.status(400).json({ success: false, message: '缺少 site 或 id 参数' });
    }
    const siteConfig = require('./services/site.json').sites.find(s => s.key === site);
    if (!siteConfig) {
      return res.status(404).json({ success: false, message: '站点不存在' });
    }
    const detail = await vod.getProviderDetail(siteConfig, id);
    if (detail && detail.sources.length > 0) {
      detail.sources.sort((a, b) => {
        if (a.hasM3u8 && !b.hasM3u8) return -1;
        if (!a.hasM3u8 && b.hasM3u8) return 1;
        return 0;
      });
      res.json({ success: true, data: { found: true, ...detail } });
    } else {
      res.json({ success: true, data: { found: false, sources: [], name: detail?.name ?? '', pic: detail?.pic ?? '' } });
    }
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/vod/category', async (req, res) => {
  try {
    const { typeId, page = 1 } = req.query;
    if (!typeId) {
      return res.status(400).json({ success: false, message: '缺少 typeId 参数' });
    }
    const results = await vod.getCategoryList('ffzy', Number(typeId), Number(page));
    res.json({ success: true, data: results });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.get('/api/vod/multi-search', async (req, res) => {
  try {
    const { keyword } = req.query;
    if (!keyword) {
      return res.status(400).json({ success: false, message: '缺少 keyword 参数' });
    }
    const results = await vod.multiSearch(keyword);
    res.json({ success: true, data: results });
  } catch (error) {
    console.error('[VOD] Multi-search error:', error.message);
    res.status(500).json({ success: false, message: error.message });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on http://0.0.0.0:${PORT}`);
});
