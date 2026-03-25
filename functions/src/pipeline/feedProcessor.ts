import * as cheerio from 'cheerio';
import { generateArticleId } from '../identity/articleHasher';

interface FeedItem {
    link?: string;
    title?: string;
    description?: string;
    content?: string;
    pubDate?: string;
    [key: string]: any;
}

interface ProcessedArticle {
    id: string;
    originalUrl: string;
    title: string;
    cleanDescription: string;
    publishedAt: Date;
    metadata: {
        rawLength: number;
        cleanLength: number;
        processingTimeMs: number;
    };
}

/**
 * Processes a raw RSS feed item into a clean, identifiable article object.
 * 
 * @param item The raw item from the RSS parser.
 * @returns A clean ProcessedArticle object.
 */
export async function processFeedItem(item: FeedItem): Promise<ProcessedArticle> {
    const startTime = Date.now();

    // 1. Validation
    if (!item.link || !item.title) {
        throw new Error('Invalid feed item: Missing link or title.');
    }

    // 2. Canonical Identity
    const id = generateArticleId(item.link, item.title);

    // 3. Content Cleaning (Cheerio)
    // Prefer full content, fallback to description
    const rawHtml = item.content || item.description || '';
    const $ = cheerio.load(rawHtml);

    // Remove scripts, styles, and empty tags
    $('script').remove();
    $('style').remove();
    $('iframe').remove();

    const cleanText = $.text().trim().replace(/\s+/g, ' ');

    // 4. Date Parsing
    const publishedAt = item.pubDate ? new Date(item.pubDate) : new Date();

    const processingTime = Date.now() - startTime;

    return {
        id,
        originalUrl: item.link,
        title: item.title.trim(),
        cleanDescription: cleanText.substring(0, 500), // Trucate for preview
        publishedAt,
        metadata: {
            rawLength: rawHtml.length,
            cleanLength: cleanText.length,
            processingTimeMs: processingTime
        }
    };
}
