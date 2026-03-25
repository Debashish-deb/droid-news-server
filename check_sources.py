#!/usr/bin/env python3
"""
RSS Feed and Website Checker
Tests all newspaper and magazine websites from data.json
"""

import json
import requests
from urllib.parse import urlparse
import time

def check_url(url, timeout=10):
    """Check if a URL is accessible"""
    try:
        response = requests.head(url, timeout=timeout, allow_redirects=True)
        return {
            'url': url,
            'status': response.status_code,
            'accessible': response.status_code < 400,
            'error': None
        }
    except requests.exceptions.Timeout:
        return {'url': url, 'status': 0, 'accessible': False, 'error': 'Timeout'}
    except requests.exceptions.ConnectionError:
        return {'url': url, 'status': 0, 'accessible': False, 'error': 'Connection Error'}
    except Exception as e:
        return {'url': url, 'status': 0, 'accessible': False, 'error': str(e)}

def main():
    # Load data.json
    with open('assets/data.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print("🔍 Testing Newspapers...")
    print("=" * 80)
    
    dead_newspapers = []
    working_newspapers = []
    
    for paper in data.get('newspapers', []):
        name = paper.get('name', 'Unknown')
        website = paper.get('contact', {}).get('website')
        
        if not website or not website.startswith('http'):
            print(f"⚠️  {name}: No valid website")
            continue
        
        print(f"Testing: {name}...", end=' ')
        result = check_url(website)
        
        if result['accessible']:
            print(f"✅ OK ({result['status']})")
            working_newspapers.append({'name': name, 'url': website, 'status': result['status']})
        else:
            print(f"❌ DEAD ({result['error']})")
            dead_newspapers.append({
                'name': name, 
                'url': website, 
                'status': result['status'],
                'error': result['error'],
                'language': paper.get('language', 'unknown'),
                'country': paper.get('country', 'unknown')
            })
        
        time.sleep(0.5)  # Be nice to servers
    
    print("\n" + "=" * 80)
    print("🔍 Testing Magazines...")
    print("=" * 80)
    
    dead_magazines = []
    working_magazines = []
    
    for mag in data.get('magazines', []):
        name = mag.get('name', 'Unknown')
        website = mag.get('contact', {}).get('website')
        
        if not website or not website.startswith('http'):
            print(f"⚠️  {name}: No valid website")
            continue
        
        print(f"Testing: {name}...", end=' ')
        result = check_url(website)
        
        if result['accessible']:
            print(f"✅ OK ({result['status']})")
            working_magazines.append({'name': name, 'url': website, 'status': result['status']})
        else:
            print(f"❌ DEAD ({result['error']})")
            dead_magazines.append({
                'name': name,
                'url': website,
                'status': result['status'],
                'error': result['error'],
                'language': mag.get('language', 'unknown'),
                'country': mag.get('country', 'unknown')
            })
        
        time.sleep(0.5)
    
    # Print summary
    print("\n" + "=" * 80)
    print("📊 SUMMARY")
    print("=" * 80)
    print(f"\n📰 Newspapers:")
    print(f"   ✅ Working: {len(working_newspapers)}")
    print(f"   ❌ Dead: {len(dead_newspapers)}")
    
    print(f"\n📖 Magazines:")
    print(f"   ✅ Working: {len(working_magazines)}")
    print(f"   ❌ Dead: {len(dead_magazines)}")
    
    # Save dead links to file
    with open('docs/DEAD_LINKS_REPORT.json', 'w') as f:
        json.dump({
            'newspapers': dead_newspapers,
            'magazines': dead_magazines
        }, f, indent=2)
    
    print(f"\n💾 Dead links saved to: docs/DEAD_LINKS_REPORT.json")
    
    # Print dead newspapers
    if dead_newspapers:
        print("\n" + "=" * 80)
        print("❌ DEAD NEWSPAPERS:")
        print("=" * 80)
        for paper in dead_newspapers:
            print(f"  • {paper['name']} ({paper['language']}/{paper['country']})")
            print(f"    URL: {paper['url']}")
            print(f"    Error: {paper['error']}\n")
    
    # Print dead magazines
    if dead_magazines:
        print("\n" + "=" * 80)
        print("❌ DEAD MAGAZINES:")
        print("=" * 80)
        for mag in dead_magazines:
            print(f"  • {mag['name']} ({mag['language']}/{mag['country']})")
            print(f"    URL: {mag['url']}")
            print(f"    Error: {mag['error']}\n")

if __name__ == '__main__':
    main()
