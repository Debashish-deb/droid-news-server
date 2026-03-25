import Bottleneck from 'bottleneck';

/**
 * Global Rate Limiter for Content Extraction
 * 
 * Strategy: Token Bucket
 * - Max 5 requests per second per IP (simulated - strictly speaking per instance)
 * - Prevents scraping abuse and manages downstream API costs.
 */
const limiter = new Bottleneck({
    minTime: 200, // Minimum 200ms between requests (5 req/sec)
    maxConcurrent: 10, // Max concurrent extractions
    reservoir: 50, // Initial tokens
    reservoirRefreshAmount: 50,
    reservoirRefreshInterval: 60 * 1000, // Refill 50 tokens every minute
});

export async function rateLimitedExecute<T>(fn: () => Promise<T>): Promise<T> {
    return limiter.schedule(fn);
}
