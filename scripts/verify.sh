#!/usr/bin/env bash
# Kataloq – full verification run (Phase 5).
# Runs every automated check and the backend end-to-end smoke test, and prints a summary
# that can be pasted into docs/TESTING.md. Nothing here is mocked except where stated.
#
#   ./scripts/verify.sh                       # uses "iPhone 18 Pro"
#   SIMULATOR="iPhone 17" ./scripts/verify.sh
#
# Requirements: Node 24+, Docker with Compose v2, Xcode 27+. Ports 3000, 8025, 1025 free.

set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 18 Pro}"
API="http://localhost:${KATALOQ_API_PORT:-3000}"
MAILPIT="http://localhost:${MAILPIT_UI_PORT:-8025}"
RESULTS=()
FAILED=0

record() { # name, status, detail
  RESULTS+=("$(printf '%-48s %-5s %s' "$1" "$2" "$3")")
  if [[ "$2" == "FAIL" ]]; then FAILED=1; fi
  return 0 # so "check && record PASS || record FAIL" never records both
}

json() { node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);console.log($1)}catch(e){console.log('INVALID_JSON')}})"; }

echo "== 1. Backend: typecheck, unit + integration tests, build"
pushd backend >/dev/null
npm ci --no-audit --no-fund >/dev/null 2>&1 || { record "backend npm ci" FAIL ""; }
if npm run typecheck >/tmp/kataloq-typecheck.log 2>&1; then record "backend typecheck" PASS ""; else record "backend typecheck" FAIL "see /tmp/kataloq-typecheck.log"; fi
NO_COLOR=1 FORCE_COLOR=0 npx vitest run >/tmp/kataloq-vitest.log 2>&1; VITEST=$?
# Strip any ANSI colour codes before reading the summary line.
SUMMARY=$(sed $'s/\x1b\\[[0-9;]*m//g' /tmp/kataloq-vitest.log | grep -E "Tests +[0-9]+" | tail -1 | sed 's/^ *//')
if [[ $VITEST -eq 0 ]]; then record "backend tests (vitest)" PASS "$SUMMARY"; else record "backend tests (vitest)" FAIL "$SUMMARY"; fi
if npm run build >/tmp/kataloq-build.log 2>&1; then record "backend build" PASS ""; else record "backend build" FAIL "see /tmp/kataloq-build.log"; fi
popd >/dev/null

echo "== 2. Docker Compose: build and start kataloq-api + Mailpit"
docker compose down --remove-orphans >/dev/null 2>&1
if docker compose up --build -d >/tmp/kataloq-compose.log 2>&1; then
  record "docker compose up --build" PASS ""
else
  record "docker compose up --build" FAIL "see /tmp/kataloq-compose.log"
  echo "---- last 25 lines of /tmp/kataloq-compose.log ----"; tail -25 /tmp/kataloq-compose.log
  echo "---- docker compose ps -a ----"; docker compose ps -a
  echo "---- what is listening on 3000 / 8025 / 1025 ----"; lsof -nP -iTCP:3000,8025,1025 -sTCP:LISTEN 2>/dev/null || true
fi
for _ in $(seq 1 30); do curl -sf "$API/health" >/dev/null && break; sleep 2; done
HEALTH=$(curl -s "$API/health")
[[ "$HEALTH" == '{"status":"ok"}' ]] && record "GET /health" PASS "" || record "GET /health" FAIL "$HEALTH"
record "compose service health" INFO "$(docker compose ps --format '{{.Service}}={{.Health}}' | tr '\n' ' ')"

echo "== 3. End-to-end smoke test against live Fake Store and Mailpit"
FEATURED=$(curl -s "$API/api/v1/products/featured" | json "j.products.map(p=>p.id+':'+p.category.id).join(' ')")
[[ $(wc -w <<<"$FEATURED") -eq 5 ]] && record "AC1 featured = 5 configured products" PASS "$FEATURED" || record "AC1 featured = 5 configured products" FAIL "$FEATURED"

CATS=$(curl -s "$API/api/v1/categories" | json "j.categories.map(c=>c.id).join(' ')")
[[ -n "$CATS" && "$CATS" != INVALID_JSON ]] && record "categories" PASS "$CATS" || record "categories" FAIL "$CATS"

CAT=$(curl -s "$API/api/v1/categories/electronics/products" | json "(()=>{const a=[...j.topRated,...j.additional];const sorted=a.every((p,i)=>i===0||a[i-1].rating.average>p.rating.average||(a[i-1].rating.average===p.rating.average&&a[i-1].rating.count>=p.rating.count));const unique=new Set(a.map(p=>p.id)).size===a.length;const same=a.every(p=>p.category.id==='electronics');return [j.topRated.length===3&&sorted&&unique&&same?'OK':'BAD','top='+j.topRated.map(p=>p.id),'rest='+j.additional.map(p=>p.id)].join(' ')})()")
[[ "$CAT" == OK* ]] && record "AC2 category: top 3 by rating, rest, no dupes" PASS "${CAT#OK }" || record "AC2 category: top 3 by rating, rest, no dupes" FAIL "$CAT"

SEARCH=$(curl -s "$API/api/v1/products/search?q=JACKET" | json "(()=>{const ok=j.products.length>0&&j.products.every(p=>(p.title+' '+p.description+' '+p.category.name).toLowerCase().includes('jacket'));return (ok?'OK ':'BAD ')+j.products.map(p=>p.id).join(',')})()")
[[ "$SEARCH" == OK* ]] && record "AC3 search 'JACKET' only matching, case-insens." PASS "${SEARCH#OK }" || record "AC3 search 'JACKET' only matching" FAIL "$SEARCH"
NOMATCH=$(curl -s "$API/api/v1/products/search?q=zzzunicorn" | json "j.products.length")
[[ "$NOMATCH" == 0 ]] && record "search with no matches -> empty list" PASS "" || record "search with no matches -> empty list" FAIL "$NOMATCH"
BLANK=$(curl -s -o /dev/null -w '%{http_code}' "$API/api/v1/products/search?q=%20")
[[ "$BLANK" == 400 ]] && record "blank search -> 400" PASS "" || record "blank search -> 400" FAIL "$BLANK"

DETAIL=$(curl -s "$API/api/v1/products/1" | json "[j.product.title,j.product.price.amount,j.product.category.name,j.product.rating.average].join(' | ')")
[[ "$DETAIL" != INVALID_JSON && -n "$DETAIL" ]] && record "AC4 product details" PASS "$DETAIL" || record "AC4 product details" FAIL "$DETAIL"
NOTFOUND=$(curl -s -o /dev/null -w '%{http_code}' "$API/api/v1/products/999")
[[ "$NOTFOUND" == 404 ]] && record "unknown product -> 404" PASS "" || record "unknown product -> 404" FAIL "$NOTFOUND"

curl -s -X DELETE "$MAILPIT/api/v1/messages" >/dev/null
INVALID=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/api/v1/enquiries" -H 'Content-Type: application/json' -d '{"productId":"1","name":"J","email":"nope"}')
[[ "$INVALID" == 400 ]] && record "invalid enquiry -> 400" PASS "" || record "invalid enquiry -> 400" FAIL "$INVALID"
ENQ=$(curl -s -w ' %{http_code}' -X POST "$API/api/v1/enquiries" -H 'Content-Type: application/json' \
  -d '{"productId":"5","name":"Verify Script","email":"verify@example.com","phone":"+61 400 000 000","message":"Automated E2E check"}')
[[ "$ENQ" == *" 202" ]] && record "AC5 enquiry accepted (202)" PASS "${ENQ% 202}" || record "AC5 enquiry accepted (202)" FAIL "$ENQ"
sleep 1
MAIL=$(curl -s "$MAILPIT/api/v1/messages" | json "j.total+' email(s): '+(j.messages[0]?j.messages[0].Subject+' -> '+j.messages[0].To.map(t=>t.Address).join(','):'none')")
[[ "$MAIL" == 1\ email* ]] && record "AC5 email captured in Mailpit" PASS "$MAIL" || record "AC5 email captured in Mailpit" FAIL "$MAIL"

docker compose stop mailpit >/dev/null 2>&1
DOWN=$(curl -s -w ' %{http_code}' -X POST "$API/api/v1/enquiries" -H 'Content-Type: application/json' -d '{"productId":"1","name":"Verify Script","email":"verify@example.com"}')
[[ "$DOWN" == *EMAIL_DELIVERY_FAILED*" 502" ]] && record "email provider down -> 502, never 202" PASS "" || record "email provider down -> 502, never 202" FAIL "$DOWN"
docker compose start mailpit >/dev/null 2>&1

echo "== 4. iOS: build and run XCTest on '$SIMULATOR'"
xcodebuild test -project ios/Kataloq.xcodeproj -scheme Kataloq \
  -destination "platform=iOS Simulator,name=$SIMULATOR" >/tmp/kataloq-xcodebuild.log 2>&1; XCODE=$?
XCSUM=$(grep -E "Executed [0-9]+ tests" /tmp/kataloq-xcodebuild.log | tail -1 | sed 's/^ *//')
if [[ $XCODE -eq 0 ]]; then record "iOS XCTest" PASS "$XCSUM"; else record "iOS XCTest" FAIL "${XCSUM:-build failed, see /tmp/kataloq-xcodebuild.log}"; fi
grep -E "error:|Test Case .* failed" /tmp/kataloq-xcodebuild.log | head -20

echo
echo "================ Kataloq verification summary ($(date '+%Y-%m-%d %H:%M')) ================"
printf '%s\n' "${RESULTS[@]}"
echo "Stack is still running (docker compose down to stop). Mailpit inbox: $MAILPIT"
exit $FAILED
