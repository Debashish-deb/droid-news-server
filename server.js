// Import required modules
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const Parser = require('rss-parser');
const axios = require('axios');
const cheerio = require('cheerio');

// Initialize app and services
const app = express();

// ✅ SECURITY: Add Helmet middleware for HTTP headers (HSTS, CSP, etc.)
app.use(helmet());

// ✅ SECURITY: CORS configuration (restrict in production)
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" }
});
const parser = new Parser();

const PORT = process.env.PORT || 3000;

// Cache to store recent news to avoid excessive Google RSS/website hits
let cachedNews = [];
let lastFetched = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

// 🆕 Fetch and parse live Google News RSS
async function fetchLiveNews() {
  try {
    const now = Date.now();
    if (cachedNews.length > 0 && (now - lastFetched) < CACHE_DURATION) {
      console.log('⚡ Serving news from cache');
      return cachedNews;
    }

    console.log('🌐 Fetching fresh news from Google News');
    const feed = await parser.parseURL('https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en');
    const newsList = [];

    for (const item of feed.items.slice(0, 10)) { // Limit to 10 articles
      const imageUrl = await fetchOpenGraphImage(item.link);
      newsList.push({
        title: item.title,
        snippet: item.contentSnippet,
        url: item.link,
        imageUrl: imageUrl || 'https://via.placeholder.com/400x180?text=No+Image'
      });
    }

    cachedNews = newsList;
    lastFetched = now;
    return newsList;

  } catch (error) {
    console.error('❌ Error fetching live news:', error.message);
    return [];
  }
}

// 🆕 Extract OpenGraph image (og:image) from article page
async function fetchOpenGraphImage(url) {
  try {
    const { data } = await axios.get(url, { timeout: 5000 });
    const $ = cheerio.load(data);
    const ogImage = $('meta[property="og:image"]').attr('content');
    return ogImage;
  } catch (error) {
    console.warn(`⚠️ Could not fetch og:image for ${url}: ${error.message}`);
    return null;
  }
}

// Home route
app.get('/', (req, res) => {
  res.send('🚀 Droid News Server Running with Live Google News + Images!');
});

// WebSocket connection
io.on('connection', (socket) => {
  console.log('✅ Droid client connected');

  const intervalId = setInterval(async () => {
    try {
      const liveNews = await fetchLiveNews();
      if (liveNews.length > 0) {
        const randomNews = liveNews[Math.floor(Math.random() * liveNews.length)];
        socket.emit('news_update', randomNews);
      }
    } catch (error) {
      console.error('❌ Failed to send live news update:', error.message);
    }
  }, 10000); // Every 10 seconds

  socket.on('disconnect', () => {
    console.log('❌ Droid client disconnected');
    clearInterval(intervalId);
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`✅ Server running at http://localhost:${PORT}`);
});
