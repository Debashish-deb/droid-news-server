#!/bin/bash
# Test all newspaper and magazine websites from data.json

echo "🔍 Testing Newspaper & Magazine Websites"
echo "========================================"
echo ""

# Extract and test newspaper URLs
echo "📰 NEWSPAPERS:"
echo "----------------------------"

urls=$(jq -r '.newspapers[] | "\(.name)|||\ (.contact.website)"' assets/data.json)

while IFS='|||' read -r name url; do
    if [[ "$url" == "null" ]] || [[ -z "$url" ]]; then
        continue
    fi
    
    status=$(curl -I -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)
    
    if [[ $status -ge 200 ]] && [[ $status -lt 400 ]]; then
        echo "✅ $name - $status"
    else
        echo "❌ $name - $status (DEAD) - $url"
    fi
done <<< "$urls"

echo ""
echo "📖 MAGAZINES:"
echo "----------------------------"

urls=$(jq -r '.magazines[] | "\(.name)|||\(.contact.website)"' assets/data.json)

while IFS='|||' read -r name url; do
    if [[ "$url" == "null" ]] || [[ -z "$url" ]]; then
        continue
    fi
    
    status=$(curl -I -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)
    
    if [[ $status -ge 200 ]] && [[ $status -lt 400 ]]; then
        echo "✅ $name - $status"
    else
        echo "❌ $name - $status (DEAD) - $url"
    fi
done <<< "$urls"

echo ""
echo "✅ Test complete!"
