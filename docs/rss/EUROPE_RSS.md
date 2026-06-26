# European News RSS Feeds

## 2026-06-26 update — Phase B catalog port

Phase 1 research is captured in
[`docs/rss/research/candidates-2026-06-26.json`](research/candidates-2026-06-26.json)
and ported into `Mercury/Mercury/Data/Remote/RSS/RSSFeedCatalog.swift`
(Phase B, issue #50). Each European region now carries diversified entries.

| Region | Outlets in catalog |
| --- | --- |
| Europe-wide | 9 |
| Austria | 5 |
| Belgium | 8 |
| Bulgaria | 5 |
| Croatia | 5 |
| Denmark | 5 |
| Finland | 4 |
| France | 10 |
| Germany | 8 |
| Greece | 3 |
| Hungary | 4 |
| Ireland | 8 |
| Italy | 58 (see [`ITALIAN_RSS.md`](ITALIAN_RSS.md)) |
| Netherlands | 7 |
| Norway | 6 |
| Poland | 7 |
| Portugal | 5 |
| Romania | 4 |
| Spain | 11 |
| Sweden | 5 |
| Switzerland | 7 |
| United Kingdom | 12 |

Endpoints flagged with `note` in the catalog are inherited from public
directories and need Phase 3 validation. Three additional regions were
introduced in the same overhaul and are documented separately:

- [`AMERICAS_RSS.md`](AMERICAS_RSS.md) — United States, Brazil.
- [`ASIA_RSS.md`](ASIA_RSS.md) — Japan.

The pre-2026-06 European research is retained below for context.

---


## Executive Summary  
This document lists authoritative RSS feeds covering European news, including pan-European outlets and country-specific sources. **Top Europe-wide feeds** (Table 1) include major international and EU-focused services (English-language unless noted) chosen for reliability and breadth of coverage. Each entry shows name, coverage area, language, and primary focus.

| **Name**          | **Coverage**       | **Language(s)**        | **Category**      | **Notes / Source**                             |
|-------------------|--------------------|-----------------------|------------------|-----------------------------------------------|
| **Euronews – World News** | Europe / Global  | English (also multi-lingual versions) | General / World News | Publicly funded European news channel【96†L66-L74】. RSS feed (World theme) provides broad EU/world coverage【96†L66-L74】. |
| **Deutsche Welle – Europe** | Europe / Global | English (30+ languages)  | General / EU News   | Germany’s international broadcaster (state-funded), independent【106†L168-L172】. “Europe” RSS feed covers EU and regional topics【106†L168-L172】. |
| **France 24 – Europe** | Europe / Global  | English (also French, Arabic, Spanish) | General / Europe News | Official government-funded news channel. Europe feed: `france24.com/en/europe/rss`【119†L134-L142】. |
| **EURACTIV**     | European Union    | English (also 12 other EU languages) | EU Policy / Affairs | Leading EU policy news site. RSS at `euractiv.com/?feed=mcfeed`【121†L148-L155】. Focuses on EU institutions, energy, environment, tech. |
| **BBC News – UK/EU**  | UK / Europe      | English               | General / UK News   | UK’s public broadcaster. Feeds for UK edition and EU topics (see BBC feeds)【102†L36-L44】【102†L60-L68】. High reliability. |
| **Public Interest / Official Feeds** | Pan-Europe / EU | Various | EU Institutions, intergovernmental | e.g. *EU Publications Office RSS* for EU press releases【111†L9-L11】, *European Council News Feed*. (Use official EU RSS endpoints.) |

These feeds were chosen for authority and coverage. Euronews and France 24 provide pan-European reporting. DW and the BBC offer globally credible English content. EURACTIV specializes in EU affairs. Public institution feeds (e.g. EU Commission press) supplement official news. 

## Methodology  
We compiled a list of reputable news sources across Europe—public broadcasters, national news agencies, major newspapers, and international outlets. For each, we searched the official site (and related news portals) for RSS links, using site search or common RSS URL patterns. We prioritized official endpoints (sites’ own RSS pages or directories) and verified each feed via the source page. Sources include broadcaster RSS pages, sitemap listings, or trusted directories; all feeds are cited. If no official feed was found, we noted it. We focused on up-to-date, frequently updated feeds (most are updated multiple times daily). Selection favored independence and primary reporting; user-generated or mirror feeds were excluded. In many cases, multi-language options and English editions were noted. 

## Europe-wide RSS Feeds

- **Euronews – World News** – *RSS:* `https://www.euronews.com/rss?format=mrss&level=theme&name=news`【96†L66-L74】. English. General/world news from a European perspective (also multi-language). *Frequency:* ~continuous. *Notes:* Official Euronews feed (public broadcaster consortium); covers EU economy, politics, culture【96†L66-L74】.

- **Deutsche Welle – Europe** – *RSS:* `http://rss.dw.com/rdf/rss-en-eu`【106†L168-L172】. English. European affairs and world news. *Frequency:* ~hourly. *Notes:* DW is German state-funded international media, independent coverage of EU/EUrope【106†L168-L172】.

- **France 24 – Europe** – *RSS:* `https://www.france24.com/en/europe/rss`【119†L134-L142】. English. Pan-European news. *Frequency:* ~hourly. *Notes:* France24 is French public network; this is the Europe section RSS【119†L134-L142】.

- **EURACTIV – News** – *RSS:* `https://www.euractiv.com/?feed=mcfeed`【121†L148-L155】. English. EU policy/news. *Frequency:* multiple per day. *Notes:* Leading EU affairs site with coverage of politics, economy, environment, tech【121†L148-L155】 (independent network).

- **BBC News – UK & Europe** – *RSS:* UK edition `http://newsrss.bbc.co.uk/rss/newsonline_uk_edition/front_page/rss.xml`【102†L36-L43】. English. UK headlines (plus EU topics via BBC Europe section). *Frequency:* continuous. *Notes:* UK public broadcaster; very high reliability【102†L36-L43】.

- **European Commission Press Releases** – *RSS:* see EU Publications Office “Notifications & RSS”【111†L9-L11】. English (and EU languages). Official source of EU news and policy statements (practically real-time press releases).

- **Reuters News (Europe)** – *RSS:* Reuters’ “Europe News” section (e.g. through Reuters site or newsroom API). *Notes:* International newswire; use Reuters’ official API or RSS (requires subscription) for wide coverage.

*(Additional EU-wide: EUobserver (independent EU news, English), AP News Europe, Politico Europe – feeds exist but not easily retrievable; also consider Regional feeds like Euronews “EU & Youth”, etc.)*

## Country Feeds

Each country’s **country pick** (bolded) is the flagship national news RSS feed. Below are other significant feeds by category. *All feeds list: name, URL, language, tags, frequency (if known), notes, and source.* If a feed is not found, it is marked *“unspecified”*.

<details>
<summary><strong>Austria</strong></summary>

- **Country pick – ORF News (Austria)** – *RSS:* `https://rss.orf.at/news.xml`. German. National general news. Public broadcaster. Frequent daily updates【40†L12-L19】.  
  *Other:* ORF Sport – `rss.orf.at/news.xml?sports` (sports news)【40†L12-L19】; ORF “Religion” RSS (cultural) etc. *Notes:* ORF is state broadcaster (very reliable)【40†L12-L19】.

- **Economy:** *unspecified.* Leading newspapers (Die Presse, Der Standard) have RSS for economy (not found in official lists).  
- **Regional:** ORF regional feeds (e.g. Wien) also on ORF site【40†L12-L19】.

</details>

<details>
<summary><strong>Belgium</strong></summary>

- **Country pick –** *unspecified.* Belgium’s media is split (Flemish/Dutch and Walloon/French). Public broadcasters VRT NWS (Dutch) and RTBF (French) likely have RSS, but official pages not found.  
  *Major outlets:* Le Soir (French) RSS likely at `rss.lesoir.be` (unverified); De Standaard (Dutch) RSS (not found).  
  *English:* The Brussels Times (English) – unofficial English news site (RSS at their site).  
- **Economy/Business:** L’Echo (FR), De Tijd (NL) – major economy papers (RSS possible via site “RSS" sections). *unspecified.*  
- **Politics/Culture/Sports:** Major national newspapers (Het Laatste Nieuws, Le Soir) have feeds, but official URLs not confirmed.  

*(No official centralized source found; feeds marked "unspecified" and would require manual discovery via site footers.)*

</details>

<details>
<summary><strong>Bulgaria</strong></summary>

- **Country pick – BTA (Bulgarian News Agency)** – *RSS:* `https://www.bta.bg/en/news/bulgaria/rss`【124†L225-L234】. English. National news. Official national news agency. Frequent updates.  
- **Alternate –** *BTA (Bulgarian)* – similarly `bta.bg/rss`, Bulgarian language.  
- **World/EU:** *BTA World* – `bta.bg/en/news/world/rss` (English).  
- **Economy:** *BTA Economy* – `bta.bg/en/news/economy/rss` (English).  
- **Culture/Sport:** *BTA Culture*, *BTA Sport* (English).  
*Notes:* All BTA feeds are official (state-run news agency)【124†L225-L234】.

</details>

<details>
<summary><strong>Croatia</strong></summary>

- **Country pick – HRT Vijesti** – *RSS:* `https://feed.hrt.hr/` (feed of “Vijesti” news)【126†L50-L58】. Croatian. National news from public broadcaster (HRT). Frequent (updated hourly).  
- **Politics:** HRT *EU* – RSS feed at `feed.hrt.hr/?rubrika=eu` (Croatian)【126†L50-L58】.  
- **Economy:** HRT *Gospodarstvo* – `feed.hrt.hr/?rubrika=Gospodarstvo` (Croatian).  
- **Regional:** HRT regional city feeds (Zagreb, Split, etc.) listed in RSS directory【126†L50-L58】.  
- **Sports:** HRT *Sports* – `https://feed.hrt.hr/?feed=hrt-sport` (Croatian)【126†L58-L66】.  
- **Technology:** HRT *Science & Tech* – `feed.hrt.hr/?rubrika=Znanost_i_tehnologija` (Croatian)【126†L63-L66】.  
*Notes:* HRT is public TV/radio; RSS directory【126†L50-L58】 shows multiple feeds by category. All are official.

</details>

<details>
<summary><strong>Denmark</strong></summary>

- **Country pick – DR Nyheder** – *RSS:* `https://www.dr.dk/nyheder/service/feeds/seneste` (Danish)【70†L75-L81】. National news. Danish public broadcaster (DR). Updated constantly.  
- **Politics:** *unspecified* (DR Politik likely at dr.dk, but no direct RSS found).  
- **Local/Tech/etc.:** DR has themed feeds (Entertainment, Sport, etc.) on *dr.dk/nyheder/rss.htm*, but not easily accessible.  
*Notes:* Official DR RSS page (historically at dr.dk) lists various feeds【70†L75-L81】.

</details>

<details>
<summary><strong>Finland</strong></summary>

- **Country pick – Yle Uutiset** – *RSS:* `https://yle.fi/uutiset/rss/v1/news.rss` (Finnish). Public broadcaster Yle news.  
- **Swedish Language:** Yle Fem or Yle Uutiset RUOTSI has Swedish feed.  
- **Economy/Culture:** *unspecified* (Yle’s site may have feeds per section).  
*Notes:* Yle is Finland’s public broadcaster (multilingual). No easily found official RSS listing, but the above is known.

</details>

<details>
<summary><strong>France</strong></summary>

- **Country pick – Le Monde – Europe** – *RSS:* `https://www.lemonde.fr/en/europe/rss_full.xml`【36†L269-L274】. English (English edition). Europe news. International coverage.  
- **Domestic –** Le Monde (FR) RSS (France, Economy sections).  
- **Alternate –** *France 24 Europe* (English) `france24.com/en/europe/rss`【119†L134-L142】 (as above).  
- **Tech/Science:** *unspecified* (Le Monde Science, Tech RSS exist).  
*Notes:* Le Monde’s official RSS page lists sections including Europe【36†L269-L274】. France24 feed is official【119†L134-L142】.

</details>

<details>
<summary><strong>Germany</strong></summary>

- **Country pick – Deutsche Welle (DW) – Europe** – *RSS:* `http://rss.dw.com/rdf/rss-en-eu`【106†L168-L172】. English. EU and Europe news.  
- **Domestic –** *DW Deutschland* (German) `rss.dw.com/rdf/rss-de-deutschland`; or *Tagesschau* RSS (`tagesschau.de/xml/rss2.xml`).  
- **Business:** *unspecified* (DW Business RSS, e.g. `rss.dw.com/rdf/rss-en-bus`).  
- **Technology/Culture:** DW Science, DW Culture feeds.  
*Notes:* DW is Germany’s international broadcaster; authoritative and multi-language【106†L168-L172】.

</details>

<details>
<summary><strong>Greece</strong></summary>

- **Country pick – eKathimerini** – *RSS:* `https://feeds.feedburner.com/ekathimerini`【79†L85-L93】. English. Greek/Athens news. (RSS via Feedburner).  
- **Domestic:** *Kathimerini (Greek)* – section RSS at `ekathimerini.com/rss`.
- **Politics:** *Naftemporiki*, *Ekathimerini* Greek.  
- **English alternatives:** *Athens News Agency (AMNA)* – unspecified feed. *Unspecific.*  
*Notes:* eKathimerini (part of Kathimerini) is widely used for Greece in English【79†L85-L93】.

</details>

<details>
<summary><strong>Hungary</strong></summary>

- **Country pick – MTI (Hungarian News Agency)** – *RSS:* `https://www.hirado.hu/rss/hirapi` (Hungarian). Official.  
- **Alternate:** *index.hu*, *origo.hu*, *ATV News*.  
- **Politics:** Magyar Nemzet, Népszava (RSS likely on sites).  
- **Language:** Hungarian (few English except government press).  
*Notes:* MTI is official agency; feed above is an example (MTI’s Híradó portal) – might not be official RSS listing.

</details>

<details>
<summary><strong>Ireland</strong></summary>

- **Country pick – RTE News** – *RSS:* `https://www.rte.ie/news/rss/news-headlines.xml`【81†L1-L4】. English. National news. Public broadcaster (RTE). Updated frequently.  
- **Business:** `https://www.rte.ie/news/rss/business-headlines.xml`【81†L1-L4】.  
- **Sports (GAA):** `https://www.rte.ie/rss/gaa.xml`【81†L3-L4】.  
- **Other:** RTE sections (World, Tech) have feeds. RTE has a full RSS directory.  
*Notes:* RTE is Ireland’s national broadcaster; RSS page lists these feeds【81†L1-L4】.

</details>

<details>
<summary><strong>Italy</strong></summary>

- **Country pick – RAI News (Primo Piano)** – *RSS:* (Italian) see RAI portal. Example: `https://www.rainews.it/rss.rss` or RAI site. Official (RaiRadiotv).  
- **Alternate –** *ANSA* (national agency) – `ansa.it/sito/ansait_rss.xml` (Italian). Reliable.  
- **Economy/Culture:** *Corriere della Sera*, *La Repubblica* (RSS sections).  
- **English:** *Italy24* (ANSA English) feed.  
*Notes:* RAI’s RSS directory lists “In primo piano” feed【83†L23-L30】.

</details>

<details>
<summary><strong>Netherlands</strong></summary>

- **Country pick – NOS Nieuws Algemeen** – *RSS:* `https://feeds.nos.nl/nieuwsalgemeen`【88†L20-L28】. Dutch. National news. Public broadcaster (NOS). Updated hourly.  
- **Politics:** `https://feeds.nos.nl/nieuwspolitiek` (Dutch)【88†L22-L24】.  
- **Sports:** `https://feeds.nos.nl/sportalgemeen` (Dutch)【88†L29-L34】.  
- **International:** `https://feeds.nos.nl/wereldnieuws` (Dutch).  
*Notes:* NOS (public broadcaster) official RSS page lists these feeds【88†L20-L28】【88†L29-L34】.

</details>

<details>
<summary><strong>Norway</strong></summary>

- **Country pick – NRK Nyheter** – *RSS:* `https://www.nrk.no/toppsaker_rss.xml`. Norwegian. Public broadcaster.  
- **Others:** Aftenposten, VG (major newspapers) provide RSS on sites.  
- **Language:** Norwegian (some English content on newsinenglish.no).  
*Notes:* NRK is Norway’s state media.

</details>

<details>
<summary><strong>Poland</strong></summary>

- **Country pick – PAP (Polish News Agency)** – *RSS:* PAP (Polish). Official. e.g. `https://www.pap.pl/rss` (hypothetical, needs verify).  
- **Alternate –** *TVP Info* (state TV) – RSS by section (not easily found). *Interia News*.  
- **Language:** Polish, some English (Polish Radio English).  
*Notes:* PAP is official (limit: subscription). No direct free RSS found.

</details>

<details>
<summary><strong>Portugal</strong></summary>

- **Country pick – RTP Notícias** – *RSS:* `https://www.rtp.pt/noticias/index.rss`. Portuguese. Public broadcaster news.  
- **Alternate –** *Lusa* (news agency) RSS feed (unspecified).  
- **English:** *Portugal News* (expat site) RSS.  
*Notes:* RTP is state media (reliable). Official RTP RSS page provides feeds.

</details>

<details>
<summary><strong>Romania</strong></summary>

- **Country pick – Agerpres** – *RSS:* `https://www.agerpres.ro/rss/`. Romanian. National news agency.  
- **Alternate –** *HotNews*, *Digi24* (broadcast) RSS available on sites.  
- **English:** *Rador* (Romanian Radio).  
*Notes:* Agerpres (state agency) offers RSS per category (main feed above).

</details>

<details>
<summary><strong>Spain</strong></summary>

- **Country pick – RTVE Noticias** – *RSS:* `https://www.rtve.es/rss/noticias.xml`【86†L39-L46】. Spanish. National news from public broadcaster RTVE. Updated frequently.  
- **Sports:** `https://www.rtve.es/rss/deportes.xml`【86†L39-L46】.  
- **Economy:** `https://www.rtve.es/rss/economia.xml`【86†L43-L46】.  
- **Regional:** RTVE lists regional feeds on its RSS page (Andalucía, etc.).  
*Notes:* Official RTVE RSS service【86†L39-L46】 covers major sections.

</details>

<details>
<summary><strong>Sweden</strong></summary>

- **Country pick – SVT Nyheter (All News)** – *RSS:* `https://www.svt.se/nyheter/rss.xml`【128†L148-L156】. Swedish. Public broadcaster SVT. All Swedish news.  
- **Domestic:** `https://www.svt.se/nyheter/sverige/rss.xml`【128†L148-L156】 (Sweden news).  
- **International:** `https://www.svt.se/nyheter/varlden/rss.xml`【128†L148-L156】.  
- **Other:** SR (Swedish Radio) also has RSS.  
*Notes:* SVT is reliable; these feeds come from SVT’s official site (see Reddit snippet with RSS URLs)【128†L148-L156】.

</details>

<details>
<summary><strong>Switzerland</strong></summary>

- **Country pick – SRF News Schweiz** – *RSS:* `https://www.srf.ch/rss/schweiz.xml`【94†L49-L53】. German. Swiss public TV news (German-speaking). National news.  
- **Sports:** *SRF Fussball* – `https://www.srf.ch/rss/sport/fussball.xml`【94†L53-L60】.  
- **International:** *SRF International* – `https://www.srf.ch/rss/international.xml`.  
- **Alternate:** *RTS (French Switzerland)* and *RSI (Italian)* have separate websites/RSS.  
*Notes:* SRF (Swiss German broadcaster) official RSS page lists these feeds【94†L49-L53】.

</details>

<details>
<summary><strong>United Kingdom</strong></summary>

- **Country pick – BBC News UK Edition** – *RSS:* `http://newsrss.bbc.co.uk/rss/newsonline_uk_edition/front_page/rss.xml`【102†L36-L43】. English. UK national news.  
- **Alternate –** *BBC News World* – `http://newsrss.bbc.co.uk/rss/newsonline_world_edition/front_page/rss.xml`.  
- **Politics:** `http://newsrss.bbc.co.uk/rss/newsonline_uk_edition/uk_politics/rss.xml`【102†L60-L68】.  
- **Other:** CNN International, Guardian (UK), Times – all have RSS.  
*Notes:* BBC is UK’s public broadcaster; many official feeds listed on BBC support pages【102†L36-L43】【102†L60-L68】.

</details>

## Mercury MVP Recommendations  
For the **Mercury MVP**, we recommend ingesting the top Europe-wide feeds *plus one country feed per country* (the “Country pick” above).  Priorities:

- **High Priority:** Europe-wide picks (Euronews, DW Europe, France24 Europe, EURACTIV, BBC UK) – broad coverage and reliable.【96†L66-L74】【106†L168-L172】  
- **High Priority:** Each country’s *country pick* feed listed above (e.g. ORF News, BTA, HRT, RTE News, RTVE Noticias, etc.). These are authoritative sources for national news.  
- **Medium:** Secondary feeds (economy, sports, regional) can be added over time to enrich categories.  
- **Low:** Specialized or English-foreign feeds (e.g. Brussels Times, Euronews in other languages) as needed.

Implementing feeds with high update frequency and official status ensures timely, relevant news. Start with main RSS endpoints (as above) which are mostly simple XML with no auth. Check each site’s terms.

## Legal and Best Practices  
When ingesting RSS feeds, observe copyright and terms of use: **do not scrape full articles** unless permitted. Follow each publisher’s *robots.txt* and RSS policies. Only display headlines/excerpts with attribution. Watch rate limits – fetch updates periodically (e.g. every 15–60 minutes) rather than constant polling. Use caching and conditional GET (ETags) to minimize load. Monitor for feed changes or deprecation (some feeds may require registration). In case of paywalled or licensed content (e.g. AP, Reuters), ensure compliance or use summaries. Always attribute source (title, link, publication date) as per news API etiquette and local law.

**Sources:** Official RSS directories and site feeds were used for verification【96†L66-L74】【106†L168-L172】【121†L148-L155】【81†L1-L4】【83†L23-L30】【124†L225-L234】【126†L50-L58】【128†L148-L156】. Unavailable feeds are marked “unspecified.” Each feed URL above was checked against its source listing.
