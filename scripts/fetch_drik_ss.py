#!/usr/bin/env python3
"""Build a Surya Siddhanta sample database from Drik Panchang's Bengali panjika.

RUN THIS ON YOUR OWN MACHINE.

THE TOGGLE
----------
The "Suryasiddhanta Panjika" button is a JavaScript call, not a link, so the
school travels as a cookie. Confirmed from Drik's own cookie jar:

    drik-arithmetic      = suryasiddhanta     <-- the toggle
    drik-ayanamsha-type  = chitra-paksha      <-- Lahiri; note when interpreting offsets

Both are HttpOnly and Secure, so send them over https.

IF YOU GET 403
--------------
Drik sits behind Cloudflare. A 403 means bot management rejected the request,
not that the cookie is wrong. Fixes, cheapest first:

 1. Run with the default browser-like headers (already set here) and a slower
    delay:  --delay 4
 2. Import your browser's exact request, cookies included. In DevTools, right
    click the panjika request -> Copy -> Copy as cURL, then:
        python3 fetch_drik_ss.py --curl 'curl "https://..." -H "..." ...' --set-cookie drik-arithmetic=suryasiddhanta
    The --curl parser takes the User-Agent, Accept, Accept-Language, Referer and
    Cookie headers from the pasted command.
 3. Pass the full cookie string from DevTools (includes __cf_bm, the Cloudflare
    bot-management cookie), which a bare drik-arithmetic cookie lacks:
        --cookie "drik-arithmetic=suryasiddhanta; drik-ayanamsha-type=chitra-paksha; __cf_bm=..."

Everything is cached per date under --cache-dir, so an interrupted or partly
403'd run resumes where it stopped instead of starting over.

USAGE
-----
    python3 fetch_drik_ss.py --set-cookie drik-arithmetic=suryasiddhanta \
        --start-year 2015 --end-year 2026 --step-days 9 --delay 4 \
        --out drik_ss_samples.csv
    python3 fit_surya_siddhanta.py drik_ss_samples.csv

GUARD: every page's "based on ..." line is checked; rows from a page that still
reports Bisuddhasiddhanta are discarded, and the run exits non-zero if no page
reported Surya Siddhanta.
"""
import argparse, csv, datetime as dt, gzip, io, os, random, re, shlex, sys, time
import urllib.error
import urllib.request
from urllib.parse import urlparse, parse_qsl, urlencode

BASE = "https://www.drikpanchang.com/bengali/bengali-month-panjika.html"

COOKIE_CANDIDATES = [
    'drik-arithmetic',
    'drik-panchang-arithmetic',
    'drik-arithmetic-type',
    'drik-panchang-type',
    'drik-siddhanta',
    'dpPanchangArithmetic', 'PanchangArithmetic', 'panchangArithmetic',
    'arithmetic',
]

BROWSER_HEADERS = {
    'User-Agent': ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                   '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36'),
    'Accept': ('text/html,application/xhtml+xml,application/xml;q=0.9,'
               'image/avif,image/webp,*/*;q=0.8'),
    'Accept-Language': 'en-US,en;q=0.9,bn;q=0.8',
    'Accept-Encoding': 'gzip, deflate',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Referer': 'https://www.drikpanchang.com/bengali/bengali-month-panjika.html',
    'Connection': 'keep-alive',
}

TITHI = {'pratipada':1,'dbitiya':2,'dwitiya':2,'tritiya':3,'chaturthi':4,'panchami':5,
 'shashthi':6,'saptami':7,'ashtami':8,'nabami':9,'navami':9,'dashami':10,'ekadashi':11,
 'dbadashi':12,'dwadashi':12,'trayodashi':13,'chaturdashi':14,'purnima':15,
 'amabasya':15,'amavasya':15}
NAK = ['ashwini','bharani','krittika','rohini','mrigashira','ardra','punarvasu','pushya',
 'ashlesha','magha','purva phalguni','uttara phalguni','hasta','chitra','swati','vishakha',
 'anuradha','jyeshtha','mula','purva ashadha','uttara ashadha','shravana','dhanishta',
 'shatabhisha','purva bhadrapada','uttara bhadrapada','revati']
NAK_ABBR = {'u bhadrapada':'uttara bhadrapada','p bhadrapada':'purva bhadrapada',
 'u ashadha':'uttara ashadha','p ashadha':'purva ashadha','u phalguni':'uttara phalguni',
 'p phalguni':'purva phalguni','u bhadra':'uttara bhadrapada','p bhadra':'purva bhadrapada'}
YOGA = ['vishkambha','priti','ayushmana','ayushman','saubhagya','shobhana','atiganda',
 'sukarma','dhriti','shula','ganda','vriddhi','dhruva','vyaghata','harshana','vajra',
 'siddhi','vyatipata','variyana','parigha','shiva','siddha','sadhya','shubha','shukla',
 'brahma','indra','vaidhriti']


def parse_time(s, page_date):
    m = re.match(r'(\d{1,2}):(\d{2})\s*(AM|PM)(?:\s*,\s*(\w{3})\s*(\d{1,2}))?\s*$', s.strip())
    if not m:
        return None
    hh, mm, ap, mon, day = m.groups()
    hh = int(hh) % 12
    if ap == 'PM':
        hh += 12
    d = page_date
    if day and int(day) != page_date.day:
        d = page_date + dt.timedelta(days=1)
    return dt.datetime(d.year, d.month, d.day, hh, int(mm))


def parse_rows(text, page_date):
    """(kind, target_deg, datetime) from one page.

    tithi      full index k (1..30) spans 12(k-1)..12k, 'X ends' -> 12k
    nakshatra  index i (0..26) spans 13.333i..13.333(i+1), ends -> (i+1)*13.333
    yoga       same as nakshatra
    """
    out = []
    pk = re.search(r'Paksha\s+(Shukla|Krishna)\s+Paksha', text, re.I)
    paksha = pk.group(1).capitalize() if pk else None
    for m in re.finditer(r'Tithi\s+([A-Za-z]+)\s+upto\s+([^\n]+)', text):
        name = m.group(1).lower(); t = parse_time(m.group(2), page_date)
        n = TITHI.get(name)
        if not n or not t or not paksha:
            continue
        if name == 'purnima':
            idx = 15
        elif name in ('amabasya', 'amavasya'):
            idx = 30
        else:
            idx = n if paksha == 'Shukla' else n + 15
        out.append(('tithi_end', 12.0 * idx, t))
    for m in re.finditer(r'Nakshatra\s+([A-Za-z\. ]+?)\s+upto\s+([^\n]+)', text):
        name = NAK_ABBR.get(m.group(1).strip().lower(), m.group(1).strip().lower())
        t = parse_time(m.group(2), page_date)
        if name not in NAK or not t:
            continue
        out.append(('nakshatra_end', (NAK.index(name) + 1) * 360.0 / 27.0, t))
    for m in re.finditer(r'(?<!Dainik )Yoga\s+([A-Za-z]+)\s+upto\s+([^\n]+)', text):
        name = m.group(1).strip().lower(); t = parse_time(m.group(2), page_date)
        if name not in YOGA or not t:
            continue
        out.append(('yoga_end', (YOGA.index(name) + 1) * 360.0 / 27.0, t))
    return out


def school_of(text):
    m = re.search(r'based on\s+([A-Za-z]+)', text, re.I)
    return m.group(1) if m else 'unknown'


def is_surya(text):
    return 'surya' in school_of(text).lower()


def find_toggle(html, base_params):
    anchor_re = re.compile(r'<a\b[^>]*?href\s*=\s*(["\'])(.+?)\1[^>]*>(.*?)</a>', re.S | re.I)
    for m in anchor_re.finditer(html):
        href = m.group(2)
        inner = m.group(3) + ' ' + re.sub(r'<[^>]+>', ' ', m.group(3))
        if 'surya' not in inner.lower() and 'surya' not in href.lower():
            continue
        if href.lower().startswith('javascript:'):
            toks = re.findall(r"['\"]([^'\"]+)['\"]", href)
            token = next((t for t in toks if 'surya' in t.lower()), 'suryasiddhanta')
            return {'kind': 'js', 'token': token, 'raw': href}
        q = dict(parse_qsl(urlparse(href).query))
        extra = {k: v for k, v in q.items() if k not in base_params}
        if extra:
            return {'kind': 'param', 'params': extra, 'raw': href}
    return None


def to_text(html):
    t = re.sub(r'<script.*?</script>', ' ', html, flags=re.S | re.I)
    t = re.sub(r'<style.*?</style>', ' ', t, flags=re.S | re.I)
    t = re.sub(r'<br\s*/?>', '\n', t, flags=re.I)
    t = re.sub(r'</(div|tr|p|li|h\d)>', '\n', t, flags=re.I)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = t.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>')
    return re.sub(r'[ \t]+', ' ', t)


def parse_curl(cmd):
    """Pull headers and URL out of a pasted 'Copy as cURL' command."""
    try:
        parts = shlex.split(cmd.replace('\\\n', ' '))
    except ValueError:
        return {}, ''
    headers, url = {}, ''
    i = 0
    while i < len(parts):
        p = parts[i]
        if p in ('-H', '--header') and i + 1 < len(parts):
            if ':' in parts[i + 1]:
                k, v = parts[i + 1].split(':', 1)
                headers[k.strip()] = v.strip()
            i += 2; continue
        if p in ('-A', '--user-agent') and i + 1 < len(parts):
            headers['User-Agent'] = parts[i + 1]; i += 2; continue
        if p.startswith('http'):
            url = p
        i += 1
    return headers, url


def fetch(url, cookie, headers, delay, tries, verbose=True):
    hdrs = dict(BROWSER_HEADERS)
    hdrs.update(headers or {})
    if cookie:
        hdrs['Cookie'] = cookie
    last = None
    for attempt in range(tries):
        if attempt:
            wait = min(60, 5 * (2 ** (attempt - 1))) + random.uniform(0, 3)
            if verbose:
                print(f'    retry {attempt}/{tries - 1} in {wait:.0f}s ({last})', file=sys.stderr)
            time.sleep(wait)
        time.sleep(delay + random.uniform(0, 1.0))
        try:
            req = urllib.request.Request(url, headers=hdrs)
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                if r.headers.get('Content-Encoding') == 'gzip':
                    raw = gzip.decompress(raw)
                return raw.decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            last = f'HTTP {e.code}'
            if e.code not in (403, 429, 500, 502, 503, 504):
                raise
        except Exception as e:
            last = type(e).__name__
    raise RuntimeError(last or 'fetch failed')


def jd_from_local(d, tz_offset_h):
    tz = dt.timezone(dt.timedelta(hours=tz_offset_h))
    return 2440587.5 + d.replace(tzinfo=tz).timestamp() / 86400.0


def main():
    argv, cleaned = sys.argv[1:], []
    for x in sys.argv[1:]:
        if x.strip() in ('', '\\'):
            continue
        if x != x.lstrip() and x.lstrip().startswith('-'):
            x = x.lstrip()
        cleaned.append(x)
    if cleaned != argv:
        print("note: stripped line-continuation artifacts from the arguments.", file=sys.stderr)
    argv = cleaned

    ap = argparse.ArgumentParser()
    ap.add_argument('--probe', action='store_true')
    ap.add_argument('--start-year', type=int, default=2000)
    ap.add_argument('--end-year', type=int, default=2026)
    ap.add_argument('--step-days', type=int, default=9)
    ap.add_argument('--geoname-id', default='1277297', help='Barasat, West Bengal')
    ap.add_argument('--tz-offset-h', type=float, default=5.5)
    ap.add_argument('--param', default='')
    ap.add_argument('--set-cookie', action='append', default=[], metavar='NAME=VALUE')
    ap.add_argument('--cookie', default='')
    ap.add_argument('--curl', default='', help="pasted 'Copy as cURL' command")
    ap.add_argument('--delay', type=float, default=4.0)
    ap.add_argument('--tries', type=int, default=3)
    ap.add_argument('--cache-dir', default='.drik_cache')
    ap.add_argument('--refetch', action='store_true', help='ignore cached pages')
    ap.add_argument('--max-pages', type=int, default=0)
    ap.add_argument('--abort-after', type=int, default=8,
                    help='abort if this many consecutive pages fail (0 = never)')
    ap.add_argument('--out', default='drik_ss_samples.csv')
    a = ap.parse_args(argv)

    curl_headers, _ = parse_curl(a.curl) if a.curl else ({}, '')
    if curl_headers.get('Cookie') and not (a.cookie or a.set_cookie):
        a.cookie = curl_headers.pop('Cookie')
        print('using the Cookie header from --curl')
    os.makedirs(a.cache_dir, exist_ok=True)

    def cookie_header(extra=None):
        if a.cookie:
            return a.cookie
        pairs = list(a.set_cookie) + ([extra] if extra else [])
        return '; '.join(pairs)

    def url_for(d, params=None):
        q = {'date': d.strftime('%d/%m/%Y'), 'geoname-id': a.geoname_id}
        if params:
            q.update(params)
        u = f'{BASE}?{urlencode(q)}'
        return u + (('&' + a.param.lstrip('&?')) if a.param else '')

    def get_page(d, params=None):
        """Fetch with a per-date disk cache."""
        cache = os.path.join(a.cache_dir, d.strftime('%Y-%m-%d') + '.html')
        if not a.refetch and os.path.exists(cache):
            with open(cache, encoding='utf-8', errors='replace') as fh:
                return fh.read(), 'cache'
        html = fetch(url_for(d, params), cookie_header(), curl_headers, a.delay, a.tries)
        with open(cache, 'w', encoding='utf-8') as fh:
            fh.write(html)
        return html, 'net'

    probe_day = dt.date(2026, 10, 27)

    if a.probe:
        html, src = get_page(probe_day)
        tog = find_toggle(html, {'date', 'geoname-id'})
        print(f'toggle: {tog}')
        print(f'default school: {school_of(to_text(html))}  (from {src})')
        token = (tog or {}).get('token', 'suryasiddhanta')
        for name in COOKIE_CANDIDATES:
            cand = f'{name}={token}'
            try:
                h = fetch(url_for(probe_day), cookie_header(cand), curl_headers, a.delay, 1)
            except Exception as e:
                print(f'  {name:30} failed: {e}'); continue
            txt = to_text(h)
            print(f'  {name:30} -> {school_of(txt):18} {"<== WORKS" if is_surya(txt) else ""}')
            if is_surya(txt):
                print(f"\nUse:\n  --set-cookie {cand}")
                return
        return

    toggle_params = None
    rows, pages_ss, pages_other, fetched, fails, streak = [], 0, 0, 0, 0, 0
    day, end = dt.date(a.start_year, 1, 1), dt.date(a.end_year, 12, 31)
    while day <= end:
        if a.max_pages and fetched >= a.max_pages:
            break
        try:
            html, src = get_page(day, toggle_params)
        except Exception as e:
            fails += 1; streak += 1
            print(f'  {day} failed: {e}', file=sys.stderr)
            if a.abort_after and streak >= a.abort_after:
                print(f'\nABORTING: {streak} consecutive failures. That is bot protection, not a')
                print('bad cookie. Try  --delay 8, or import your browser request with --curl,')
                print('or pass the full --cookie string including __cf_bm.')
                print('Pages already fetched are cached in ' + a.cache_dir)
                break
            day += dt.timedelta(days=a.step_days); continue
        streak = 0
        fetched += 1
        txt = to_text(html)
        if not is_surya(txt):
            pages_other += 1
            day += dt.timedelta(days=a.step_days); continue
        pages_ss += 1
        for kind, target, when in parse_rows(txt, day):
            rows.append((kind, round(target, 5), when.strftime('%Y-%m-%d'),
                         when.strftime('%H:%M'), a.tz_offset_h,
                         round(jd_from_local(when, a.tz_offset_h), 6), day.year, '', ''))
        if fetched % 25 == 0:
            print(f'  {fetched} pages ({src}), {len(rows)} rows, up to {day}')
        day += dt.timedelta(days=a.step_days)

    with open(a.out, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['kind','target','date','time','tz_offset_h','jd','edition_year','page','notes'])
        w.writerows(rows)

    print(f'\npages fetched {fetched}: surya {pages_ss}, other school {pages_other}, failed {fails}')
    print(f'rows written {len(rows)} -> {a.out}')
    if pages_ss == 0:
        print('\nREFUSING TO CALL THIS VALID: no page reported the Surya Siddhanta school.')
        sys.exit(2)
    if rows:
        days = sorted({r[2] for r in rows})
        print(f'span {days[0]} .. {days[-1]}  ({len(days)} sampled days)')
        print('next: python3 fit_surya_siddhanta.py ' + a.out)


if __name__ == '__main__':
    main()
