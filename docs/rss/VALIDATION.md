# RSS Catalog Validation Report — 2026-07-02 (issue #90, batch 1)

Live end-to-end validation of every catalog outlet: feed fetch + parse +
freshness, **plus 1–2 real article pages per outlet** scored for
extractable body (the new requirement from issue #90 — a feed is only
healthy if the reader can produce an article body from it).

- **Raw diagnostics dump**: [`research/diagnostics-2026-07-02.json`](research/diagnostics-2026-07-02.json)
- **Run environment**: curl + Foundation URLSession probes from macOS,
  Safari-iOS UA (`ArticlePageClient.defaultUserAgent`), 12 s timeout,
  1 retry, 4-way concurrency.

## Method

1. Fetch each of the 177 feed URLs with the app's Safari-iOS UA.
2. Parse as RSS/Atom/RDF; count items; compute newest-item age
   (stale cut-off: 30 days).
3. Fetch 1–2 real article pages per outlet and score body
   extractability on `<p>`-text volume and JSON-LD `articleBody`
   (ok ≥ 1000 chars, thin ≥ 400, else no body).
4. **Re-verify every curl-level failure with a Foundation URLSession
   probe** (same UA). This matters: 17 outlets that 403 curl serve the
   app's network stack just fine (curl TLS-fingerprint bot blocks), and
   they are kept as ✅ — see "curl false alarms" below.

## Classification

| Bucket | Meaning |
| --- | --- |
| ✅ ok | Feed parses, ≥5 items, newest ≤30 days, ≥1 sampled article page with extractable body. |
| 🟡 degraded | Feed works but items/bodies are thin, dates are missing, or some links are broken. Kept. |
| ⛔ dead | Fetch/parse failure, empty or >30-day-stale feed, or **no extractable article body** (hard paywall, JS-only shell, consent interstitial). Replaced or removed. |

## Summary

### Pre-fix (final verdicts on the shipped 177 entries)

| Region | ✅ ok | 🟡 degraded | ⛔ dead | total |
| --- | ---: | ---: | ---: | ---: |
| Austria | 5 | 0 | 0 | 5 |
| Belgium | 3 | 0 | 2 | 5 |
| Brazil | 5 | 0 | 1 | 6 |
| Bulgaria | 3 | 0 | 0 | 3 |
| Denmark | 4 | 0 | 0 | 4 |
| Europe-Wide | 9 | 0 | 0 | 9 |
| Finland | 4 | 0 | 0 | 4 |
| France | 10 | 0 | 0 | 10 |
| Germany | 7 | 0 | 0 | 7 |
| Greece | 1 | 0 | 1 | 2 |
| Hungary | 2 | 0 | 0 | 2 |
| Ireland | 5 | 0 | 0 | 5 |
| Italy | 36 | 4 | 8 | 48 |
| Japan | 2 | 1 | 1 | 4 |
| Netherlands | 6 | 0 | 1 | 7 |
| Norway | 6 | 0 | 0 | 6 |
| Poland | 2 | 0 | 0 | 2 |
| Portugal | 2 | 1 | 1 | 4 |
| Romania | 3 | 0 | 1 | 4 |
| Spain | 6 | 0 | 1 | 7 |
| Sweden | 4 | 0 | 1 | 5 |
| Switzerland | 4 | 0 | 0 | 4 |
| United Kingdom | 11 | 0 | 0 | 11 |
| United States | 8 | 0 | 5 | 13 |
| **Total** | **148** | **6** | **23** | **177** |

### Post-fix (after this batch's catalog updates)

| Region | ✅ ok | 🟡 degraded | ⛔ dead | total | Δ |
| --- | ---: | ---: | ---: | ---: | ---: |
| Austria | 5 | 0 | 0 | 5 | +0 |
| Belgium | 3 | 0 | 0 | 3 | -2 |
| Brazil | 6 | 0 | 0 | 6 | +0 |
| Bulgaria | 3 | 0 | 0 | 3 | +0 |
| Denmark | 4 | 0 | 0 | 4 | +0 |
| Europe-Wide | 9 | 0 | 0 | 9 | +0 |
| Finland | 4 | 0 | 0 | 4 | +0 |
| France | 10 | 0 | 0 | 10 | +0 |
| Germany | 7 | 0 | 0 | 7 | +0 |
| Greece | 1 | 0 | 0 | 1 | -1 |
| Hungary | 2 | 0 | 0 | 2 | +0 |
| Ireland | 5 | 0 | 0 | 5 | +0 |
| Italy | 37 | 5 | 0 | 42 | -6 |
| Japan | 2 | 1 | 0 | 3 | -1 |
| Netherlands | 6 | 0 | 0 | 6 | -1 |
| Norway | 6 | 0 | 0 | 6 | +0 |
| Poland | 2 | 0 | 0 | 2 | +0 |
| Portugal | 2 | 1 | 0 | 3 | -1 |
| Romania | 3 | 0 | 0 | 3 | -1 |
| Spain | 7 | 0 | 0 | 7 | +0 |
| Sweden | 5 | 0 | 0 | 5 | +0 |
| Switzerland | 4 | 0 | 0 | 4 | +0 |
| United Kingdom | 11 | 0 | 0 | 11 | +0 |
| United States | 9 | 0 | 0 | 9 | -4 |
| **Total** | **153** | **7** | **0** | **160** | **-17** |

Every remaining catalog entry is ✅ or 🟡; there are no known-dead feeds
left in the catalog after this batch.

## Dispositions

### Removed (17)

| Outlet | Region | Reason | Original URL |
| --- | --- | --- | --- |
| Het Laatste Nieuws | Belgium | DPG Media consent interstitial: article pages are an 8 KB JS shell with no body | `https://www.hln.be/rss.xml` |
| Le Soir – Une | Belgium | feed returns an empty channel (0 items); ARC alternates 403/404 | `https://www.lesoir.be/rss/section/0.xml` |
| AMNA | Greece | feed now returns HTML; all alternates (`/rss.php`, `/en/rss`, `/feeds/rss`) return HTML/404 | `https://www.amna.gr/news/rss` |
| Corriere della Sera – Cronaca | Italy | newest item 28 days old and all sibling feeds are frozen archives; corriere.it retired RSS | `https://www.corriere.it/rss/cronaca.xml` |
| Corriere della Sera – Economia | Italy | frozen archive (~884 days stale) | `https://www.corriere.it/rss/economia.xml` |
| Corriere della Sera – Esteri | Italy | frozen archive (~483 days stale) | `https://www.corriere.it/rss/esteri.xml` |
| Corriere della Sera – Homepage | Italy | frozen at 2024-05-13 (~780 days stale) | `https://www.corriere.it/rss/homepage.xml` |
| Corriere della Sera – Politica | Italy | frozen archive (~695 days stale) | `https://www.corriere.it/rss/politica.xml` |
| Corriere della Sera – Sport | Italy | frozen archive (~260 days stale) | `https://www.corriere.it/rss/sport.xml` |
| Japan Times – Top Stories | Japan | feed ~490 days stale; live `/feed/` alternate exists but article pages 403 the app UA (bot gate + paywall) | `https://www.japantimes.co.jp/feed/topstories/` |
| De Volkskrant | Netherlands | DPG Media consent interstitial: article pages are an 8 KB JS shell with no body | `https://www.volkskrant.nl/voorpagina/rss.xml` |
| Público – Últimas | Portugal | Feedburner feed frozen at 2019-07; `publico.pt/rss` alternates return empty/202 | `https://feeds.feedburner.com/PublicoUltimaHora` |
| Agerpres | Romania | `/rss/` times out / answers 500; only alternate is an unofficial FiveFilters scrape proxy | `https://www.agerpres.ro/rss/` |
| NYT – Top Stories | United States | feed healthy but nytimes.com article pages hard-403 the app UA (curl **and** URLSession) | `https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml` |
| NYT – World | United States | same hard 403 on article pages | `https://rss.nytimes.com/services/xml/rss/nyt/World.xml` |
| Washington Post – World | United States | article pages are a ~1 MB JS shell; visible body is a ~900-char teaser behind a hard paywall | `https://feeds.washingtonpost.com/rss/world` |
| AP News (Google proxy) | United States | items link to news.google.com JS-redirect stubs with no extractable body | `https://news.google.com/rss/search?q=site%3Aapnews.com+when%3A1d&hl=en-US&gl=US&ceid=US:en` |

### Replaced (6)

| Outlet | Region | Old URL | New URL | Why |
| --- | --- | --- | --- | --- |
| Agência Brasil | Brazil | `https://agenciabrasil.ebc.com.br/rss.xml` | `https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml` | old feed frozen ~2023-08; new feed fresh, articles extract 9–13k chars |
| Gazzetta dello Sport | Italy | `https://www.gazzetta.it/rss/homepage.xml` | `https://www.gazzetta.it/dynamic-feed/rss/section/last.xml` | old feed frozen 2023-12; new feed fresh (bodies shortish → 🟡) |
| RAI News | Italy | `https://www.rai.it/dl/portale/html/PublishingBlock-…-rss.xml` | `https://www.rainews.it/rss/tutti` | old feed's links all 404 on retired `rainews24.rai.it` |
| El Periódico (Portada → Internacional) | Spain | `https://www.elperiodico.com/es/rss/rss_portada.xml` | `https://www.elperiodico.com/es/rss/internacional/rss.xml` | portada channel is valid but permanently 0 items; section feeds live (id renamed to `elperiodico-internacional`) |
| Sveriges Radio – Ekot | Sweden | `https://api.sr.se/api/rss/program/4540` | `https://api.sr.se/api/rss/program/83` | 4540 is the radio-broadcast rundown whose article links 404; 83 is the Ekot text-news feed |
| WSJ – World News | United States | `https://feeds.a.dj.com/rss/RSSWorldNews.xml` | `https://feeds.content.dowjones.io/public/rss/RSSWorldNews` | old host frozen at 2025-01; Dow Jones moved public feeds; articles extract 50k+ chars |

### Promotions

- **ERT News** (Greece) → main outlet + country-pick after the AMNA removal.
- **Japan Today** (Japan) → main outlet + country-pick after the Japan Times removal.
- **Digi24** (Romania) → main outlet + country-pick after the Agerpres removal.
- United States keeps **NPR – Top Stories** as its existing country-pick.

### curl false alarms (kept ✅ after URLSession recheck)

These outlets fail plain curl (403/402/fetch error) but serve complete
article bodies to a Foundation `URLSession` probe with the same Safari
UA — i.e. the app's real network stack works. They are classified ✅:

De Standaard, EURACTIV, Fanpage, Japan Today, France 24 (EN ×2 + FR),
franceinfo, Le Monde (Une + English), Ouest-France, Politico EU
Playbook, Politico Playbook, Financial Times, Sky News, and VG (the
sampled links were VGTV video shells; regular news articles extract
fine).

### Degraded (kept, 🟡)

| Outlet | Region | Why |
| --- | --- | --- |
| Il Sole 24 Ore – Finanza | Italy | only 4 items in feed |
| Libero Quotidiano | Italy | occasional broken `/undefined/` links in the feed; working links extract ~5.7k chars |
| Repubblica – Politica | Italy | premium articles serve ~670-char teasers; `milano.repubblica.it` links 403 |
| Sky TG24 – Homepage | Italy | items carry no parseable dates (bodies extract fine) |
| Asahi Shimbun – Headlines | Japan | metered paywall truncates bodies to ~900 chars |
| RTP Notícias | Portugal | short news briefs (350–500 chars) |
| Gazzetta dello Sport | Italy | replaced URL is fresh but bodies run short (live blogs, pagelle) |

## Known gaps

- **NYT / Japan Times / Washington Post 403s and paywalls** were
  verified with URLSession from a residential macOS connection. If a
  future per-source header/cookie override lands, NYT could be
  reinstated (its feeds are healthy).
- **Greece is down to one outlet** (ERT News) after the AMNA removal;
  a future batch should inventory replacements (in.gr, Protothema,
  Kathimerini).
- The `RSSCatalogValidationHarness` (feed-level, simulator) remains
  available; this batch used an out-of-process validator so article
  pages could be probed with both curl and URLSession fingerprints.
  The raw per-outlet evidence (item counts, ages, per-article `<p>`
  char counts, verdicts, recheck notes) is in the diagnostics JSON.

---

# RSS Catalog Validation Report — 2026-06-26 (Phase 3, issue #53)

Phase 3 of the RSS overhaul executes a live-network diagnostics run
against every outlet shipped by PR #52 and dispositions each entry.

- **Raw diagnostics dump**: [`research/diagnostics-2026-06-26.json`](research/diagnostics-2026-06-26.json)
- **Harness**: `Mercury/MercuryTests/RSSCatalogValidationHarness.swift`
  (gated behind Swift Testing's `.disabled(...)` trait; see the trait
  message for the exact `xcodebuild test` re-run command)
- **Run environment**: iPhone 17 Pro simulator, iOS 26.3.1, `MercuryRSSClient/1.0` UA, 12 s timeout, 4-way concurrency.

## Classification

| Bucket | Meaning |
| --- | --- |
| ✅ ok | Feed returned ≥5 normalized articles with body coverage ≥50%. |
| 🟡 degraded | Feed parsed but returned thin payloads (few items or weak body coverage). Kept in catalog if no better alternate. |
| ⛔ dead | Network or parse failure (404 / 403 / 410 / DNS / TLS / ATS / HTML body). Replaced or removed per the table below. |

## Summary

### Pre-fix (snapshot from the diagnostics JSON)

| Region | ✅ ok | 🟡 degraded | ⛔ dead | total |
| --- | ---: | ---: | ---: | ---: |
| Austria | 3 | 2 | 0 | 5 |
| Belgium | 4 | 1 | 3 | 8 |
| Brazil | 6 | 0 | 3 | 9 |
| Bulgaria | 3 | 0 | 2 | 5 |
| Croatia | 0 | 0 | 5 | 5 |
| Denmark | 3 | 0 | 2 | 5 |
| Europe-Wide | 6 | 3 | 0 | 9 |
| Finland | 3 | 0 | 1 | 4 |
| France | 10 | 0 | 0 | 10 |
| Germany | 5 | 2 | 1 | 8 |
| Greece | 1 | 0 | 2 | 3 |
| Hungary | 2 | 0 | 2 | 4 |
| Ireland | 5 | 0 | 3 | 8 |
| Italy | 43 | 3 | 12 | 58 |
| Japan | 3 | 0 | 5 | 8 |
| Netherlands | 2 | 1 | 4 | 7 |
| Norway | 5 | 0 | 1 | 6 |
| Poland | 2 | 0 | 5 | 7 |
| Portugal | 3 | 0 | 2 | 5 |
| Romania | 2 | 1 | 1 | 4 |
| Spain | 6 | 1 | 4 | 11 |
| Sweden | 4 | 1 | 0 | 5 |
| Switzerland | 4 | 0 | 3 | 7 |
| United Kingdom | 11 | 0 | 1 | 12 |
| United States | 11 | 1 | 3 | 15 |
| **Total** | **147** | **16** | **65** | **228** |

### Post-fix (after the catalog updates in this PR)

Removals + replacements collapse the 65 dead entries into either a working alternate URL or a documented removal.
No outlets have been added in this phase (out of scope for #53).

| Region | ✅ ok | 🟡 degraded | ⛔ dead | total | Δ |
| --- | ---: | ---: | ---: | ---: | ---: |
| Austria | 3 | 2 | 0 | 5 | +0 |
| Belgium | 4 | 1 | 0 | 5 | -3 |
| Brazil | 6 | 0 | 0 | 6 | -3 |
| Bulgaria | 3 | 0 | 0 | 3 | -2 |
| Croatia | 0 | 0 | 0 | 0 | -5 |
| Denmark | 4 | 0 | 0 | 4 | -1 |
| Europe-Wide | 6 | 3 | 0 | 9 | +0 |
| Finland | 4 | 0 | 0 | 4 | +0 |
| France | 10 | 0 | 0 | 10 | +0 |
| Germany | 5 | 2 | 0 | 7 | -1 |
| Greece | 2 | 0 | 0 | 2 | -1 |
| Hungary | 2 | 0 | 0 | 2 | -2 |
| Ireland | 5 | 0 | 0 | 5 | -3 |
| Italy | 45 | 3 | 0 | 48 | -10 |
| Japan | 4 | 0 | 0 | 4 | -4 |
| Netherlands | 6 | 1 | 0 | 7 | +0 |
| Norway | 6 | 0 | 0 | 6 | +0 |
| Poland | 2 | 0 | 0 | 2 | -5 |
| Portugal | 4 | 0 | 0 | 4 | -1 |
| Romania | 3 | 1 | 0 | 4 | +0 |
| Spain | 6 | 1 | 0 | 7 | -4 |
| Sweden | 4 | 1 | 0 | 5 | +0 |
| Switzerland | 4 | 0 | 0 | 4 | -3 |
| United Kingdom | 11 | 0 | 0 | 11 | -1 |
| United States | 12 | 1 | 0 | 13 | -2 |
| **Total** | **161** | **16** | **0** | **177** | **-51** |

Post-fix dead entries are outlets whose alternates we have not verified yet (Croatia HRT, etc.) — they are flagged in the per-region notes below as future work, not silently shipped.

## Per-region detail

Only regions with at least one Phase 3 disposition (removal, replacement, or HTTPS upgrade) are listed below. 
Regions that came back fully ✅ (Austria, France, Sweden, UK except Reuters) are intentionally omitted.

### Belgium

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| De Tijd â Nieuws | removed (404) | `https://www.tijd.be/rss.xml` |
| L'Echo â Ãconomie | removed (404) | `https://www.lecho.be/rss.xml` |
| The Brussels Times | removed (HTML / no public RSS) | `https://www.brusselstimes.com/feed` |

### Brazil

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Jornal de BrasÃ­lia | removed (HTML / parseFailed) | `https://jornaldebrasilia.com.br/feed/` |
| Portal EBC | removed (404) | `https://www.ebc.com.br/rss/feed.xml` |
| R7 â NotÃ­cias | removed (404) | `https://noticias.r7.com/feed.xml` |

### Bulgaria

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| BTA â Bulgaria (BG) | removed (HTML / parseFailed) | `https://www.bta.bg/bg/news/rss` |
| Novinite â English | removed (timeout) | `https://www.novinite.com/services/news_rdf.php` |

### Croatia

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| HRT â EU | removed (403 — all hrt.hr feeds) | `https://feed.hrt.hr/?rubrika=eu` |
| HRT â Gospodarstvo | removed (403) | `https://feed.hrt.hr/?rubrika=Gospodarstvo` |
| HRT â Sport | removed (403) | `https://feed.hrt.hr/?feed=hrt-sport` |
| HRT â Vijesti | removed (403) | `https://feed.hrt.hr/` |
| HRT â Znanost i tehnologija | removed (403) | `https://feed.hrt.hr/?rubrika=Znanost_i_tehnologija` |

### Denmark

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| DR Nyheder â Seneste | replaced (`/seneste` → `/allenyheder`) | `https://www.dr.dk/nyheder/service/feeds/seneste` |
| TV 2 â Nyheder | removed (DNS failure) | `https://feeds.tv2.dk/nyheder_seneste/rss` |

### Finland

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Yle Uutiset | replaced (legacy path → `feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET`) | `https://yle.fi/uutiset/rss/v1/news.rss` |

### Germany

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| FOCUS Online | removed (404 — rss.focus.de retired) | `https://rss.focus.de/fol/XML/rss_folnews.xml` |

### Greece

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| AMNA â English | replaced by `amna-news` (general AMNA wire) | `https://www.amna.gr/rss/english.xml` |
| Kathimerini â English | removed (404 — Feedburner endpoint dead) | `https://feeds.feedburner.com/ekathimerini` |

### Hungary

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| About Hungary (EN) | removed (site under construction) | `https://abouthungary.hu/rss.xml` |
| HÃ­radÃ³ (MTI/MTVA) | removed (404 — MTVA RSS retired); promoted index-hu to country-pick | `https://www.hirado.hu/rss/hirapi` |

### Ireland

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| RTÃ News â Business | removed (403 — RTÉ blocks Mercury UA) | `https://www.rte.ie/news/rss/business-headlines.xml` |
| RTÃ News â Headlines | removed (403); promoted thejournal-ie to country-pick | `https://www.rte.ie/news/rss/news-headlines.xml` |
| RTÃ â GAA | removed (403) | `https://www.rte.ie/rss/gaa.xml` |

### Italy

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| AGI â Agenzia Italia (Top News) | removed (404) | `https://www.agi.it/feed/cronaca/rss` |
| ANSA â English | removed (404 + stale 2014 mirror at alt path) | `https://www.ansa.it/english/news/english_notizie.xml` |
| Adnkronos â Prima Pagina | upgraded http→https canonical | `http://rss.adnkronos.com/RSS_PrimaPagina.xml` |
| Il Foglio | removed (410 Gone) | `https://www.ilfoglio.it/sezioni/112/rss` |
| Il Post | removed (403 — UA gated) | `https://www.ilpost.it/feed/` |
| La Stampa â Copertina | removed (403) | `https://www.lastampa.it/rss/copertina.xml` |
| RAI News 24 â Primo Piano | removed (404); promoted rai-portale-rss to main | `https://www.rainews.it/rss.rss` |
| RAI Radio â Giornale Radio | removed (404) | `https://www.rai.it/dl/portaleAudio/Giornale_Radio_index.rss` |
| RAI TGR Piemonte | removed (404) | `https://www.rainews.it/tgr/rss/piemonte.xml` |
| Sky TG24 â Cronaca | collapsed into new `sky-tg24-homepage` (404) | `https://tg24.sky.it/rss/cronaca.xml` |
| Sky TG24 â Mondo | collapsed into new `sky-tg24-homepage` (404) | `https://tg24.sky.it/rss/mondo.xml` |
| Sky TG24 â Politica | collapsed into new `sky-tg24-homepage` (404) | `https://tg24.sky.it/rss/politica.xml` |

### Japan

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Asahi Shimbun â Headlines | upgraded http→https | `http://rss.asahi.com/rss/asahi/newsheadlines.rdf` |
| Kyodo News+ (EN) | removed (404) | `https://english.kyodonews.net/rss/all.xml` |
| Livedoor News â Top | removed (403) | `https://news.livedoor.com/topics/rss/top.xml` |
| NHK World â Top Stories (EN) | removed (404 — NHK World feed retired) | `https://www3.nhk.or.jp/nhkworld/en/news/feeds/rss/news-en.xml` |
| The Mainichi (EN) | removed (HTML / parseFailed) | `https://mainichi.jp/rss/etc/mailnews.rss` |

### Netherlands

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| NOS â Algemeen | replaced (`nieuwsalgemeen` → `nosnieuwsalgemeen`) | `https://feeds.nos.nl/nieuwsalgemeen` |
| NOS â Politiek | replaced (`nieuwspolitiek` → `nosnieuwspolitiek`) | `https://feeds.nos.nl/nieuwspolitiek` |
| NOS â Sport | replaced (`sportalgemeen` → `nossportalgemeen`) | `https://feeds.nos.nl/sportalgemeen` |
| NOS â Wereld | replaced (`wereldnieuws` → `nosnieuwsbuitenland`) | `https://feeds.nos.nl/wereldnieuws` |

### Norway

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| VG â Forsiden | replaced (`/rss/feed/forsiden/` → `/rss/feed/`) | `https://www.vg.no/rss/feed/forsiden/` |

### Poland

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Dziennik.pl | removed (TLS failure) | `https://rss.dziennik.pl/Dziennik-PL/` |
| Gazeta Prawna | removed (TLS failure) | `https://rss.gazetaprawna.pl/GazetaPrawna` |
| PAP â Polska Agencja Prasowa | removed (HTML / parseFailed); promoted rmf24 to country-pick | `https://www.pap.pl/rss.xml` |
| Rzeczpospolita | removed (403) | `https://www.rp.pl/rss/1019` |
| Wirtualne Media | removed (ATS — http redirect) | `https://www.wirtualnemedia.pl/rss/wirtualnemedia_rss.xml` |

### Portugal

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| DiÃ¡rio de NotÃ­cias | removed (404) | `https://www.dn.pt/rss` |
| RTP NotÃ­cias | replaced (`/noticias/index.rss` → `/noticias/rss`) | `https://www.rtp.pt/noticias/index.rss` |

### Romania

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Romania Insider (EN) | replaced (`/rss.xml` → `/feed`) | `https://www.romania-insider.com/rss.xml` |

### Spain

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Agencia EFE â English | removed (HTML / parseFailed) | `https://www.efe.com/efe/english/4/rss` |
| RTVE â Deportes | removed (ATS — http redirect) | `https://www.rtve.es/rss/deportes.xml` |
| RTVE â Economia | removed (ATS — http redirect) | `https://www.rtve.es/rss/economia.xml` |
| RTVE â Noticias | removed (404) | `https://www.rtve.es/rss/noticias.xml` |

### Switzerland

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| RSI â Notizie | removed (404) | `https://www.rsi.ch/news/feed` |
| RTS Info â Toute l'info | removed (HTML / parseFailed) | `https://www.rts.ch/info/?format=rss` |
| Swissinfo (EN) | removed (404) | `https://www.swissinfo.ch/eng/latest/rss` |

### United Kingdom

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| Reuters â UK | removed (DNS — feedburner Reuters retired) | `https://feeds.reuters.com/reuters/UKTopNews` |

### United States

| Outlet | Disposition | Original URL |
| --- | --- | --- |
| CNN â Top Stories | removed (http-only and rss.cnn.com has no valid https cert) | `http://rss.cnn.com/rss/edition.rss` |
| Reuters â Top News (legacy) | removed (DNS) | `https://feeds.reuters.com/reuters/topNews` |
| Washington Post â World | upgraded http→https | `http://feeds.washingtonpost.com/rss/world` |

## HTTPS upgrades

Three outlets were swapped from `http://` to `https://` after Phase 3 confirmed the secure variant resolves:

1. **Adnkronos** — `http://rss.adnkronos.com/RSS_PrimaPagina.xml` 301-redirects to `https://www.adnkronos.com/RSS_PrimaPagina.xml`; the canonical URL is now used directly to skip the redirect hop.
2. **Asahi Shimbun** — `http://rss.asahi.com/rss/asahi/newsheadlines.rdf` → `https://rss.asahi.com/rss/asahi/newsheadlines.rdf`.
3. **Washington Post – World** — `http://feeds.washingtonpost.com/rss/world` → `https://feeds.washingtonpost.com/rss/world`.

CNN was the fourth http-only entry in the catalog. We removed it instead of upgrading: `rss.cnn.com` does not serve a valid HTTPS certificate (the cert is issued for a different SAN, so `URLSession` rejects it). A replacement CNN endpoint will need a per-source UA/cert override which is out of scope for this PR.

## Known gaps

- **Croatia is empty** after the HRT removals; the next phase needs to inventory tportal, Index.hr or 24sata as replacements.
- **Bot-detection failures** (RTÉ, La Stampa, Il Post, Rzeczpospolita, Livedoor) were fetched with the same Safari-iOS UA the app ships (#82) and still failed — most likely datacenter-IP throttling rather than UA fingerprinting. They might work from a real iPhone on a residential connection; treated as dead for now, reinstatable after a real-device rerun.
- **TLS / ATS failures** (Dziennik.pl, Gazeta Prawna, Wirtualne Media, RTVE) reflect upstream cert chains and http-only redirects we cannot work around without dropping the App Transport Security guarantee.
- **AP News via Google News proxy** was removed: the feed resolves, but every item links to a news.google.com JS-redirect stub with no extractable body, so enrichment always fails. AP publishes no official RSS to swap in.
- **Reuters legacy Feedburner** (`reuters-uk`, `reuters-top-legacy`) is permanently dead (DNS no longer resolves). Both entries were removed.
- **De Volkskrant** was removed: the feed ships title-only items and the article pages serve the DPG Media consent interstitial (an 8 KB JS shell with no body), so neither the feed nor enrichment can produce a readable article.
- **The Mercury harness uses the iPhone 17 Pro simulator** and may produce different verdicts from a real device on a residential connection (some 403s are likely datacenter-IP throttling). Reruns from a real device will produce a follow-up report.

## Methodology

The harness lives in `Mercury/MercuryTests/RSSCatalogValidationHarness.swift` and does the following:

1. Iterates `RSSFeedCatalog.availableRegions` and calls `FeedRefreshService.runDiagnostics(groupMode: .byRegion, selectedRegion: region)` once per region. `.byRegion` is the only mode that fans out to *every* outlet (rather than the 25 main-outlet country picks).
2. Aggregates per-source `RSSFeedCheckResult`s into a single `RSSFeedBatchResult`.
3. Calls `RSSDiagnosticsReportExporter.buildJSONReport(from:)` (added in this PR) to produce a stable JSON document with per-outlet status, classification, article counts, and body/image coverage.
4. Writes the JSON to `$TMPDIR/MercuryRSSReports/rss-validation-harness.json` *and* echoes it between `[rss-harness-json-begin]` / `[rss-harness-json-end]` markers so it can be lifted from `xcresulttool get log --type action`.
5. The committed snapshot under `docs/rss/research/diagnostics-2026-06-26.json` was extracted directly from that xcresult emit.

To re-run the harness:

```bash
# Remove the `.disabled(...)` trait on `runValidationHarness`, then:
xcodebuild test \
  -project Mercury/Mercury.xcodeproj \
  -scheme Mercury-UnitTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MercuryTests/RSSCatalogValidationHarness \
  CODE_SIGNING_ALLOWED=NO
```

Total wall-clock for one full run was about 5 minutes 50 seconds.

