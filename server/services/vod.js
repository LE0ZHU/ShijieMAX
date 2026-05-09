const axios = require('axios');

const siteConfig = require('./site.json');
const sites = (siteConfig.sites || []).filter(s => s.active && s.key);

const SEARCH_TIMEOUT = 8000;
const MAX_PROVIDERS = 5;

function parsePlayUrl(playUrl, playFrom) {
  if (!playUrl || typeof playUrl !== 'string') return [];

  const names = (playFrom && typeof playFrom === 'string')
    ? playFrom.split('$$$')
    : [];

  const sources = playUrl.split('$$$');

  return sources.map((sourceStr, index) => {
    const episodes = sourceStr.split('#').filter(Boolean).map((ep) => {
      const dollarIdx = ep.indexOf('$');
      let name = '';
      let url = '';
      if (dollarIdx >= 0) {
        name = ep.substring(0, dollarIdx);
        url = ep.substring(dollarIdx + 1);
      } else {
        url = ep;
        name = `第${episodes.length + 1}集`;
      }
      return {
        name,
        url,
        isM3u8: url.includes('.m3u8'),
      };
    });

    if (episodes.length === 0) return null;

    return {
      sourceName: names[index] || `source${index + 1}`,
      episodes,
      hasM3u8: episodes.some(e => e.isM3u8),
    };
  }).filter(Boolean);
}

async function searchProvider(site, keyword) {
  try {
    const response = await axios.get(site.api, {
      params: { ac: 'list', wd: keyword, pg: 1 },
      timeout: SEARCH_TIMEOUT,
    });

    const data = response.data;
    if (data && data.code === 1 && Array.isArray(data.list) && data.list.length > 0) {
      return data.list.map(item => ({
        vodId: item.vod_id,
        name: item.vod_name,
        pic: item.vod_pic,
        remark: item.vod_remarks || '',
        typeName: item.type_name || '',
        siteKey: site.key,
        siteName: site.name,
      }));
    }
    return [];
  } catch (err) {
    console.warn(`[VOD] ${site.name} search failed:`, err.message);
    return [];
  }
}

async function getProviderDetail(site, vodId) {
  try {
    const response = await axios.get(site.api, {
      params: { ac: 'detail', ids: vodId },
      timeout: SEARCH_TIMEOUT,
    });

    const data = response.data;
    if (data && data.code === 1 && Array.isArray(data.list) && data.list.length > 0) {
      const item = data.list[0];
      return {
        vodId: item.vod_id,
        name: item.vod_name,
        pic: item.vod_pic,
        typeName: item.type_name || '',
        remark: item.vod_remarks || '',
        year: item.vod_year || '',
        area: item.vod_area || '',
        lang: item.vod_lang || '',
        actor: item.vod_actor || '',
        director: item.vod_director || '',
        description: (item.vod_blurb || item.vod_content || '').replace(/<\/?[^>]+(>|$)/g, ''),
        sources: parsePlayUrl(item.vod_play_url, item.vod_play_from)
          .filter(s => s.hasM3u8),
      };
    }
    return null;
  } catch (err) {
    console.warn(`[VOD] ${site.name} detail failed:`, err.message);
    return null;
  }
}

async function multiSearch(keyword) {
  const activeSites = sites.slice(0, 8);
  const allResults = [];

  const promises = activeSites.map(async (site) => {
    const matches = await searchProvider(site, keyword);
    return matches.map(item => ({
      ...item,
      siteKey: site.key,
      siteName: site.name,
    }));
  });

  const results = await Promise.all(promises);
  for (const siteResults of results) {
    allResults.push(...siteResults);
  }

  // Deduplicate by name similarity
  const seen = new Set();
  return allResults.filter(item => {
    const key = item.name.toLowerCase().trim();
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

async function getCategoryList(siteKey, typeId, page = 1) {
  const site = sites.find(s => s.key === siteKey) || sites[0];
  if (!site) return [];

  try {
    const response = await axios.get(site.api, {
      params: { ac: 'videolist', t: typeId, pg: page },
      timeout: SEARCH_TIMEOUT,
    });

    const data = response.data;
    if (data && data.code === 1 && Array.isArray(data.list)) {
      return data.list.map(item => ({
        vodId: item.vod_id,
        name: item.vod_name,
        pic: item.vod_pic || '',
        remark: item.vod_remarks || '',
        typeName: item.type_name || '',
        siteKey: site.key,
        siteName: site.name,
      }));
    }
    return [];
  } catch (err) {
    console.warn(`[VOD] Category ${typeId} from ${site.name} failed:`, err.message);
    return [];
  }
}

async function searchAndResolve(chiTitle, origTitle) {
  const activeSites = sites.slice(0, MAX_PROVIDERS);

  const searchTitles = [chiTitle];
  if (origTitle && origTitle !== chiTitle) {
    searchTitles.push(origTitle);
  }

  for (const title of searchTitles) {
    for (const site of activeSites) {
      const matches = await searchProvider(site, title);
      if (matches.length > 0) {
        const detail = await getProviderDetail(site, matches[0].vodId);
        if (detail && detail.sources.length > 0) {
          detail.sources.sort((a, b) => {
            if (a.hasM3u8 && !b.hasM3u8) return -1;
            if (!a.hasM3u8 && b.hasM3u8) return 1;
            return 0;
          });
          return { found: true, ...detail };
        }
      }
    }
  }

  return { found: false, sources: [], name: '', pic: '' };
}

module.exports = { searchAndResolve, parsePlayUrl, multiSearch, getProviderDetail, getCategoryList };
