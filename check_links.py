import json
import urllib.request
import urllib.error
import ssl
import sys
import socket

# Ignore SSL errors for this check as some valid sites might have expired certs but are "alive"
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def check_url(url):
    if not url:
        return False, "Empty URL"
    try:
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'}
        )
        with urllib.request.urlopen(req, context=ctx, timeout=3) as response:
            return True, response.getcode()
    except urllib.error.HTTPError as e:
        return False, e.code
    except urllib.error.URLError as e:
        return False, str(e.reason)
    except socket.timeout:
        return False, "Timeout"
    except Exception as e:
        return False, str(e)

def main():
    try:
        with open('assets/data.json', 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading JSON: {e}")
        return

    dead_links = []
    
    # Heuristic to find lists of items
    categories = [k for k, v in data.items() if isinstance(v, list)]
    
    print(f"Scanning categories: {categories}", flush=True)

    for category in categories:
        items = data[category]
        print(f"Checking {len(items)} items in {category}...", flush=True)
        
        for item in items:
            name = item.get('name', 'Unknown')
            id = item.get('id', 'Unknown')
            
            # Check website
            website = item.get('contact', {}).get('website')
            if website:
                is_alive, status = check_url(website)
                if not is_alive:
                    print(f"[DEAD] {name} ({id}): {website} -> {status}", flush=True)
                    dead_links.append({
                        'category': category,
                        'name': name,
                        'id': id,
                        'url': website,
                        'error': status
                    })
            else:
                 # Some might not have a website listed
                 pass

    print("\n" + "="*30)
    print(f"Found {len(dead_links)} dead links:")
    for link in dead_links:
        print(f"- [{link['category']}] {link['name']} ({link['id']}): {link['url']} (Reason: {link['error']})")

if __name__ == "__main__":
    main()
