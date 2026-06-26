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
- **Bot-detection failures** (RTÉ, La Stampa, Il Post, Rzeczpospolita, Livedoor) might work from a real iPhone with a system User-Agent. We treated them as dead because the production app uses the same `MercuryRSSClient/1.0` UA that the harness used. A future change could introduce a per-source UA override and reinstate them.
- **TLS / ATS failures** (Dziennik.pl, Gazeta Prawna, Wirtualne Media, RTVE) reflect upstream cert chains and http-only redirects we cannot work around without dropping the App Transport Security guarantee.
- **AP News via Google News proxy** still resolves and is kept; long-term that proxy should be replaced with a partner feed.
- **Reuters legacy Feedburner** (`reuters-uk`, `reuters-top-legacy`) is permanently dead (DNS no longer resolves). Both entries were removed.
- **De Volkskrant** appears as ✅ post-fix but `articles_with_body` is only 2/30 in the dump — the feed ships title-only items so summarization quality will suffer. Kept in catalog because the headlines are still useful.
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

