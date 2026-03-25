import * as crypto from 'crypto';

/**
 * Generates a canonical ID for an article based on its URL and title.
 * 
 * This ensures that the same article from the same source always produces
 * the same ID, allowing for robust deduplication.
 * 
 * @param url The article URL.
 * @param title The article title.
 * @returns A unique string ID starting with "v1_".
 */
export function generateArticleId(url: string, title: string): string {
    // 1. Normalize URL: Remove query parameters and fragments
    let normalizedUrl = url;
    try {
        const parsedUrl = new URL(url);
        // Keep only protocol, host, and pathname
        normalizedUrl = `${parsedUrl.protocol}//${parsedUrl.host}${parsedUrl.pathname}`;
        // Remove trailing slash
        if (normalizedUrl.endsWith('/')) {
            normalizedUrl = normalizedUrl.slice(0, -1);
        }
    } catch {
        // Fallback for invalid URLs: Use raw string but trim
        normalizedUrl = url.trim();
    }

    // 2. Normalize Title: Lowercase, trim, remove excessive whitespace
    const normalizedTitle = title
        .toLowerCase()
        .trim()
        .replace(/\s+/g, ' ');

    // 3. Create MD5 Hash
    const rawString = `${normalizedUrl}|${normalizedTitle}`;
    const hash = crypto.createHash('md5').update(rawString).digest('hex');

    // 4. Return Versioned ID
    return `v1_${hash}`;
}
