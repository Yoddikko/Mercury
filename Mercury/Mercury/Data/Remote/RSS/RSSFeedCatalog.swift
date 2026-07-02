//
//  RSSFeedCatalog.swift
//  Mercury
//
//  Created by Codex on 01/04/26.
//
//  Catalog of RSS sources powering the home feed and the developer
//  diagnostics. Entries are grouped by region; within each region they
//  are listed alphabetically by outlet name so review diffs stay tidy.
//
//  Source of truth for the URLs: `docs/rss/research/candidates-2026-06-26.json`
//  harvested during Phase 1 (issue #50), validated live in Phase 3 (issue #53)
//  and re-validated end-to-end (feed + real article pages) on 2026-07-02 for
//  issue #90 — see `docs/rss/VALIDATION.md` and
//  `docs/rss/research/diagnostics-2026-07-02.json` for the dispositions.
//

import Foundation

enum RSSFeedCatalog {
    static let allSources: [RSSFeedSource] = {
        var sources: [RSSFeedSource] = []
        sources.append(contentsOf: europeWideSources)
        sources.append(contentsOf: austriaSources)
        sources.append(contentsOf: belgiumSources)
        sources.append(contentsOf: brazilSources)
        sources.append(contentsOf: bulgariaSources)
        sources.append(contentsOf: croatiaSources)
        sources.append(contentsOf: denmarkSources)
        sources.append(contentsOf: finlandSources)
        sources.append(contentsOf: franceSources)
        sources.append(contentsOf: germanySources)
        sources.append(contentsOf: greeceSources)
        sources.append(contentsOf: hungarySources)
        sources.append(contentsOf: irelandSources)
        sources.append(contentsOf: italySources)
        sources.append(contentsOf: japanSources)
        sources.append(contentsOf: netherlandsSources)
        sources.append(contentsOf: norwaySources)
        sources.append(contentsOf: polandSources)
        sources.append(contentsOf: portugalSources)
        sources.append(contentsOf: romaniaSources)
        sources.append(contentsOf: spainSources)
        sources.append(contentsOf: swedenSources)
        sources.append(contentsOf: switzerlandSources)
        sources.append(contentsOf: unitedKingdomSources)
        sources.append(contentsOf: unitedStatesSources)
        return sources
    }()

    static var availableRegions: [RSSFeedRegion] {
        RSSFeedRegion.allCases.filter { region in
            allSources.contains { $0.region == region }
        }
    }

    static func sources(
        for groupMode: RSSFeedGroupMode,
        region: RSSFeedRegion?
    ) -> [RSSFeedSource] {
        let filtered: [RSSFeedSource]
        switch groupMode {
        case .allOutlets:
            filtered = allSources
        case .mainOutlets:
            filtered = allSources.filter(\.isMainOutlet)
        case .byRegion:
            guard let region else { return [] }
            filtered = allSources.filter { $0.region == region }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.region.rawValue != rhs.region.rawValue {
                return lhs.region.rawValue < rhs.region.rawValue
            }
            return lhs.outletName.localizedCaseInsensitiveCompare(rhs.outletName) == .orderedAscending
        }
    }

    // MARK: - Europe-Wide

    private static let europeWideSources: [RSSFeedSource] = [
        source(
            id: "bbc-world",
            outlet: "BBC News – World",
            region: .europeWide,
            url: "https://feeds.bbci.co.uk/news/world/rss.xml",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "dw-all-en",
            outlet: "Deutsche Welle – All (EN)",
            region: .europeWide,
            url: "https://rss.dw.com/rdf/rss-en-all",
            language: "en",
            tags: ["wire", "world"]
        ),
        source(
            id: "dw-europe-en",
            outlet: "Deutsche Welle – Europe (EN)",
            region: .europeWide,
            url: "https://rss.dw.com/rdf/rss-en-eu",
            main: true,
            language: "en",
            tags: ["general", "europe"]
        ),
        source(
            id: "euractiv-news",
            outlet: "EURACTIV – News",
            region: .europeWide,
            url: "https://www.euractiv.com/?feed=mcfeed",
            main: true,
            language: "en",
            tags: ["eu", "policy"]
        ),
        source(
            id: "euronews-world",
            outlet: "Euronews – World",
            region: .europeWide,
            url: "https://www.euronews.com/rss?format=mrss&level=theme&name=news",
            main: true,
            language: "en",
            tags: ["general", "world"]
        ),
        source(
            id: "france24-europe-en",
            outlet: "France 24 – Europe (EN)",
            region: .europeWide,
            url: "https://www.france24.com/en/europe/rss",
            main: true,
            language: "en",
            tags: ["general", "europe"]
        ),
        source(
            id: "france24-top-en",
            outlet: "France 24 – Top stories (EN)",
            region: .europeWide,
            url: "https://www.france24.com/en/rss",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "guardian-world",
            outlet: "The Guardian – World",
            region: .europeWide,
            url: "https://www.theguardian.com/world/rss",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "politico-eu-playbook",
            outlet: "Politico Europe – Playbook",
            region: .europeWide,
            url: "https://rss.politico.com/playbook.xml",
            language: "en",
            tags: ["eu", "politics"]
        )
    ]

    // MARK: - Austria

    private static let austriaSources: [RSSFeedSource] = [
        source(
            id: "derstandard-international",
            outlet: "Der Standard – International",
            region: .austria,
            url: "https://www.derstandard.at/rss/international",
            language: "de",
            tags: ["world"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "diepresse-politik",
            outlet: "Die Presse – Politik",
            region: .austria,
            url: "https://www.diepresse.com/rss/Politik",
            language: "de",
            tags: ["politics"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "kleinezeitung",
            outlet: "Kleine Zeitung",
            region: .austria,
            url: "https://www.kleinezeitung.at/rss/",
            language: "de",
            tags: ["regional"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "orf-news",
            outlet: "ORF – News",
            region: .austria,
            url: "https://rss.orf.at/news.xml",
            main: true,
            language: "de",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "orf-sport",
            outlet: "ORF – Sport",
            region: .austria,
            url: "https://rss.orf.at/news.xml?sports",
            language: "de",
            tags: ["sports"]
        )
    ]

    // MARK: - Belgium

    private static let belgiumSources: [RSSFeedSource] = [
        // Removed in Phase 3 (#53): `brussels-times` returned HTML on
        // 2026-06-26 (parseFailed); upstream RSS appears retired. No
        // verified alternate found.
        source(
            id: "destandaard-nieuws",
            outlet: "De Standaard – Nieuws",
            region: .belgium,
            url: "https://www.standaard.be/rss/section/1f2838d4-99ea-49f0-9102-138784c7ea7c",
            language: "nl",
            tags: ["general"],
            note: "Section UUID to verify in Phase 3."
        ),
        // Removed in Phase 3 (#53): `detijd-nieuws` returned HTTP 404 on
        // 2026-06-26; De Tijd has no public RSS index anymore.
        // Removed in live validation (#90): `hln` article pages serve
        // the DPG Media consent interstitial (an 8 KB JS shell with no
        // article body), so enrichment can never extract content.
        // Removed in Phase 3 (#53): `lecho` returned HTTP 404 on
        // 2026-06-26; L'Echo's RSS endpoint is no longer published.
        // Removed in live validation (#90): `lesoir-une` returns an
        // empty channel (0 items); the ARC outbound-feed alternates
        // answer 403/404.
        source(
            id: "rtbf-belgique",
            outlet: "RTBF Info – Belgique",
            region: .belgium,
            url: "https://rss.rtbf.be/article/rss/highlight_rtbf_info-belgique.xml",
            main: true,
            language: "fr",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "rtbf-top",
            outlet: "RTBF Info – Top stories",
            region: .belgium,
            url: "https://rss.rtbf.be/article/rss/highlight_rtbf_info.xml",
            language: "fr",
            tags: ["general"]
        )
    ]

    // MARK: - Brazil

    private static let brazilSources: [RSSFeedSource] = [
        source(
            id: "agencia-brasil",
            outlet: "Agência Brasil",
            region: .brazil,
            // Replaced in live validation (#90): `/rss.xml` is a frozen
            // archive (newest item ~2023-08). The `ultimasnoticias`
            // feed is the live endpoint.
            url: "https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml",
            language: "pt",
            tags: ["wire"]
        ),
        source(
            id: "brasil-wire-en",
            outlet: "Brasil Wire (EN)",
            region: .brazil,
            url: "https://www.brasilwire.com/feed/",
            language: "en",
            tags: ["english", "analysis"]
        ),
        // Removed in Phase 3 (#53): `ebc-portal` returned HTTP 404 on
        // 2026-06-26. EBC (Agência Brasil) is still served via the
        // `agencia-brasil` entry above; the portal endpoint is dead.
        source(
            id: "folha-emcima",
            outlet: "Folha de S.Paulo – Em cima da hora",
            region: .brazil,
            url: "https://feeds.folha.uol.com.br/emcimadahora/rss091.xml",
            main: true,
            language: "pt",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "g1-globo",
            outlet: "G1 – Globo",
            region: .brazil,
            url: "https://g1.globo.com/rss/g1/",
            main: true,
            language: "pt",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        // Removed in Phase 3 (#53): `jornaldebrasilia` returned HTML
        // (parseFailed) on 2026-06-26; their /feed/ endpoint now serves
        // a maintenance page.
        // Removed in Phase 3 (#53): `r7-noticias` returned HTTP 404 on
        // 2026-06-26; R7 no longer publishes a single global RSS file.
        source(
            id: "riotimes-en",
            outlet: "The Rio Times (EN)",
            region: .brazil,
            url: "https://riotimesonline.com/feed/",
            language: "en",
            tags: ["english"]
        ),
        source(
            id: "uol-home",
            outlet: "UOL",
            region: .brazil,
            url: "https://rss.home.uol.com.br/index.xml",
            language: "pt",
            tags: ["general"]
        )
    ]

    // MARK: - Bulgaria

    private static let bulgariaSources: [RSSFeedSource] = [
        // Removed in Phase 3 (#53): `bta-bg` served HTML on 2026-06-26
        // (parseFailed). The Bulgarian-language RSS endpoint appears to
        // be blocked behind bot detection; the EN variants below still
        // work.
        source(
            id: "bta-bulgaria-en",
            outlet: "BTA – Bulgaria (EN)",
            region: .bulgaria,
            url: "https://www.bta.bg/en/news/bulgaria/rss",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "bta-economy-en",
            outlet: "BTA – Economy (EN)",
            region: .bulgaria,
            url: "https://www.bta.bg/en/news/economy/rss",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "bta-world-en",
            outlet: "BTA – World (EN)",
            region: .bulgaria,
            url: "https://www.bta.bg/en/news/world/rss",
            language: "en",
            tags: ["world"]
        ),
        // Removed in Phase 3 (#53): `novinite-en` timed out repeatedly on
        // 2026-06-26 (the host did not respond within the 12 s timeout).
        // No verified alternate endpoint found.
    ]

    // MARK: - Croatia

    // Phase 3 (#53): every `feed.hrt.hr` endpoint we shipped returned
    // HTTP 403 on 2026-06-26 from the simulator (likely bot detection
    // or per-IP throttling). No HRT-hosted alternate is publicly
    // documented today, so the Croatian region currently has no live
    // outlets in the catalog. A future phase should source a Croatian
    // publisher with a stable RSS surface (e.g. tportal, Index.hr,
    // 24sata).
    private static let croatiaSources: [RSSFeedSource] = []

    // MARK: - Denmark

    private static let denmarkSources: [RSSFeedSource] = [
        source(
            id: "dr-indland",
            outlet: "DR Nyheder – Indland",
            region: .denmark,
            url: "https://www.dr.dk/nyheder/service/feeds/indland",
            language: "da",
            tags: ["national"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "dr-seneste",
            outlet: "DR Nyheder – Alle Nyheder",
            region: .denmark,
            // Replaced in Phase 3 (#53): the legacy `/seneste` endpoint
            // returned HTTP 404 on 2026-06-26. `/allenyheder` is DR's
            // current public-facing aggregate feed and serves the same
            // top-headlines mix.
            url: "https://www.dr.dk/nyheder/service/feeds/allenyheder",
            main: true,
            language: "da",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "dr-udland",
            outlet: "DR Nyheder – Udland",
            region: .denmark,
            url: "https://www.dr.dk/nyheder/service/feeds/udland",
            language: "da",
            tags: ["world"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "politiken-forside",
            outlet: "Politiken – Forside",
            region: .denmark,
            url: "https://politiken.dk/rss/senestenyt.rss",
            language: "da",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        // Removed in Phase 3 (#53): `tv2-nyheder` failed DNS lookup on
        // 2026-06-26 (host `feeds.tv2.dk` not found). TV 2 no longer
        // publishes a public newsroom RSS at this hostname.
    ]

    // MARK: - Finland

    private static let finlandSources: [RSSFeedSource] = [
        source(
            id: "helsinki-times-en",
            outlet: "Helsinki Times (EN)",
            region: .finland,
            url: "https://www.helsinkitimes.fi/?format=feed&type=rss",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "hs-etusivu",
            outlet: "Helsingin Sanomat – Etusivu",
            region: .finland,
            url: "https://www.hs.fi/rss/tuoreimmat.xml",
            language: "fi",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "yle-news-en",
            outlet: "Yle News (EN)",
            region: .finland,
            url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_NEWS&concepts=18-34837",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "yle-uutiset",
            outlet: "Yle Uutiset",
            region: .finland,
            // Replaced in Phase 3 (#53): legacy `/uutiset/rss/v1/news.rss`
            // returned HTTP 404 on 2026-06-26. The current canonical
            // endpoint is `feeds.yle.fi/uutiset/v1/recent.rss` with
            // `publisherIds=YLE_UUTISET` (matches Yle's own RSS index).
            url: "https://feeds.yle.fi/uutiset/v1/recent.rss?publisherIds=YLE_UUTISET",
            main: true,
            language: "fi",
            tags: ["general", "country-pick"]
        )
    ]

    // MARK: - France

    private static let franceSources: [RSSFeedSource] = [
        source(
            id: "france24-top-fr",
            outlet: "France 24 – Top stories (EN)",
            region: .france,
            url: "https://www.france24.com/en/rss",
            language: "en",
            tags: ["international"]
        ),
        source(
            id: "franceinfo-titres",
            outlet: "France Info – Titres",
            region: .france,
            url: "https://www.francetvinfo.fr/titres.rss",
            language: "fr",
            tags: ["broadcast"]
        ),
        source(
            id: "huffpost-fr",
            outlet: "Le HuffPost France",
            region: .france,
            url: "https://www.huffingtonpost.fr/feeds/index.xml",
            language: "fr",
            tags: ["digital"]
        ),
        source(
            id: "ladepeche",
            outlet: "La Dépêche du Midi",
            region: .france,
            url: "https://www.ladepeche.fr/rss.xml",
            language: "fr",
            tags: ["regional"]
        ),
        source(
            id: "lemonde-europe-en",
            outlet: "Le Monde – Europe (EN)",
            region: .france,
            url: "https://www.lemonde.fr/en/europe/rss_full.xml",
            language: "en",
            tags: ["europe"]
        ),
        source(
            id: "lemonde-une",
            outlet: "Le Monde – À la une",
            region: .france,
            url: "https://www.lemonde.fr/rss/une.xml",
            main: true,
            language: "fr",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "lobs-une",
            outlet: "L'Obs – À la une",
            region: .france,
            url: "https://www.nouvelobs.com/a-la-une/rss.xml",
            language: "fr",
            tags: ["general"]
        ),
        source(
            id: "mediapart-articles",
            outlet: "Mediapart – Articles",
            region: .france,
            url: "https://www.mediapart.fr/articles/feed",
            language: "fr",
            tags: ["investigative"],
            note: "Paywalled feed: summaries only."
        ),
        source(
            id: "ouestfrance-encontinu",
            outlet: "Ouest-France – En continu",
            region: .france,
            url: "https://www.ouest-france.fr/rss-en-continu.xml",
            language: "fr",
            tags: ["regional"]
        ),
        source(
            id: "sudouest-essentiel",
            outlet: "Sud Ouest – Essentiel",
            region: .france,
            url: "https://www.sudouest.fr/essentiel/rss.xml",
            language: "fr",
            tags: ["regional"]
        )
    ]

    // MARK: - Germany

    private static let germanySources: [RSSFeedSource] = [
        source(
            id: "dw-business-en-de",
            outlet: "Deutsche Welle – Business (EN)",
            region: .germany,
            url: "https://rss.dw.com/rdf/rss-en-bus",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "dw-deutschland-de",
            outlet: "Deutsche Welle – Deutschland (DE)",
            region: .germany,
            url: "https://rss.dw.com/rdf/rss-de-deutschland",
            language: "de",
            tags: ["general"]
        ),
        source(
            id: "faz-aktuell",
            outlet: "FAZ – Aktuell",
            region: .germany,
            url: "https://www.faz.net/rss/aktuell/",
            language: "de",
            tags: ["general"]
        ),
        // Removed in Phase 3 (#53): `focus-online` returned HTTP 404 on
        // 2026-06-26. FOCUS sunset their legacy `rss.focus.de` host;
        // no documented replacement at the previous outlet category
        // level.
        source(
            id: "spiegel-schlagzeilen",
            outlet: "Spiegel Online – Schlagzeilen",
            region: .germany,
            url: "https://www.spiegel.de/schlagzeilen/index.rss",
            language: "de",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "sueddeutsche-topthemen",
            outlet: "Süddeutsche Zeitung – Topthemen",
            region: .germany,
            url: "https://rss.sueddeutsche.de/rss/Topthemen",
            language: "de",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "tagesschau",
            outlet: "Tagesschau",
            region: .germany,
            url: "https://www.tagesschau.de/xml/rss2/",
            main: true,
            language: "de",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "zeit-online-index",
            outlet: "ZEIT ONLINE – Index",
            region: .germany,
            url: "https://newsfeed.zeit.de/index",
            language: "de",
            tags: ["general"]
        )
    ]

    // MARK: - Greece

    private static let greeceSources: [RSSFeedSource] = [
        // Removed in live validation (#90): `amna-news` at `/news/rss`
        // now returns HTML; every tested alternate (`/rss.php`,
        // `/en/rss`, `/feeds/rss`) also answers HTML or 404. ERT News
        // below inherits the country-pick role.
        source(
            id: "ertnews",
            outlet: "ERT News",
            region: .greece,
            url: "https://www.ertnews.gr/feed/",
            main: true,
            language: "el",
            tags: ["public-broadcaster", "country-pick"],
            note: "Promoted to main outlet in #90 after the AMNA removal."
        )
        // Removed in Phase 3 (#53): `kathimerini-en` at
        // `feeds.feedburner.com/ekathimerini` returned HTTP 404 on
        // 2026-06-26. Feedburner has stopped fanning out this feed and
        // ekathimerini.com no longer documents an English RSS URL.
        // AMNA above is promoted to the country-pick role.
    ]

    // MARK: - Hungary

    private static let hungarySources: [RSSFeedSource] = [
        // Removed in Phase 3 (#53): `abouthungary-en` returned HTML
        // ("site under construction") on 2026-06-26 (parseFailed).
        // The site is currently being rebuilt; no replacement exists.
        // Removed in Phase 3 (#53): `hirado-mti` returned HTTP 404 on
        // 2026-06-26. MTI/MTVA retired the public `/rss/hirapi` API;
        // their press-only API requires authentication. `index-hu`
        // below is promoted to the country-pick role.
        source(
            id: "index-hu",
            outlet: "Index.hu",
            region: .hungary,
            url: "https://index.hu/24ora/rss",
            main: true,
            language: "hu",
            tags: ["digital", "country-pick"],
            note: "Promoted to main outlet in Phase 3 after MTVA retirement."
        ),
        source(
            id: "telex-hu",
            outlet: "Telex.hu",
            region: .hungary,
            url: "https://telex.hu/rss",
            language: "hu",
            tags: ["digital"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - Ireland

    private static let irelandSources: [RSSFeedSource] = [
        source(
            id: "breakingnews-ie",
            outlet: "BreakingNews.ie",
            region: .ireland,
            url: "https://feeds.breakingnews.ie/bntopstories",
            language: "en",
            tags: ["digital"]
        ),
        source(
            id: "irish-examiner",
            outlet: "Irish Examiner – Top Stories",
            region: .ireland,
            url: "https://feeds.feedburner.com/ietopstories",
            language: "en",
            tags: ["regional"]
        ),
        source(
            id: "irish-mirror",
            outlet: "Irish Mirror",
            region: .ireland,
            url: "https://www.irishmirror.ie/?service=rss",
            language: "en",
            tags: ["tabloid"]
        ),
        // Removed in Phase 3 (#53): every `www.rte.ie` feed returned
        // HTTP 403 on 2026-06-26 (RTÉ rejects the MercuryRSSClient
        // User-Agent; the same URLs work in a desktop browser but the
        // app-side client cannot reach them). `thejournal-ie` below is
        // promoted to the country-pick role until RTÉ either relaxes
        // the block or we add per-source UA overrides.
        source(
            id: "the42-sport",
            outlet: "The42 (Sport)",
            region: .ireland,
            url: "https://www.the42.ie/feed/",
            language: "en",
            tags: ["sports"]
        ),
        source(
            id: "thejournal-ie",
            outlet: "TheJournal.ie",
            region: .ireland,
            url: "https://www.thejournal.ie/feed/",
            main: true,
            language: "en",
            tags: ["digital", "country-pick"],
            note: "Promoted to country-pick in Phase 3 after RTÉ block."
        )
    ]

    // MARK: - Italy

    private static let italySources: [RSSFeedSource] = [
        source(
            id: "adnkronos-prima",
            outlet: "Adnkronos – Prima Pagina",
            region: .italy,
            // Upgraded to HTTPS in Phase 3 (#53). The legacy
            // `http://rss.adnkronos.com/` host 301-redirects to
            // `https://www.adnkronos.com/<path>`; the canonical URL
            // below skips the redirect and works in MercuryRSSClient
            // (which rejects insecure transport).
            url: "https://www.adnkronos.com/RSS_PrimaPagina.xml",
            language: "it",
            tags: ["wire"]
        ),
        // Removed in Phase 3 (#53): `agi-cronaca` returned HTTP 404 on
        // 2026-06-26. AGI no longer publishes per-section RSS at this
        // path; their homepage feed is also gone.
        source(
            id: "ansa-cronaca",
            outlet: "ANSA – Cronaca",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/cronaca/cronaca_rss.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "ansa-cultura",
            outlet: "ANSA – Cultura",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/cultura/cultura_rss.xml",
            language: "it",
            tags: ["culture"]
        ),
        source(
            id: "ansa-economia",
            outlet: "ANSA – Economia",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/economia/economia_rss.xml",
            language: "it",
            tags: ["economy"]
        ),
        // Removed in Phase 3 (#53): `ansa-english` at
        // `/english/news/english_notizie.xml` returned HTTP 404 on
        // 2026-06-26. The legacy `/news/english_rss.xml` variant still
        // resolves but only serves a stale 2014 snapshot, so we drop
        // ANSA's English edition entirely. The ANSA Italian feeds
        // below remain healthy.
        source(
            id: "ansa-homepage",
            outlet: "ANSA – Homepage",
            region: .italy,
            url: "https://www.ansa.it/sito/ansait_rss.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "ansa-lifestyle",
            outlet: "ANSA – Lifestyle",
            region: .italy,
            url: "https://www.ansa.it/canale_lifestyle/notizie/lifestyle_rss.xml",
            language: "it",
            tags: ["lifestyle"]
        ),
        source(
            id: "ansa-mondo",
            outlet: "ANSA – Mondo",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/mondo/mondo_rss.xml",
            language: "it",
            tags: ["world"]
        ),
        source(
            id: "ansa-politica",
            outlet: "ANSA – Politica",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/politica/politica_rss.xml",
            language: "it",
            tags: ["politics"]
        ),
        source(
            id: "ansa-salute-benessere",
            outlet: "ANSA – Salute & Benessere",
            region: .italy,
            url: "https://www.ansa.it/canale_saluteebenessere/notizie/saluteebenessere_rss.xml",
            language: "it",
            tags: ["health"]
        ),
        source(
            id: "ansa-scienza",
            outlet: "ANSA – Scienza",
            region: .italy,
            url: "https://www.ansa.it/canale_scienza_tecnica/notizie/scienzaetecnica_rss.xml",
            language: "it",
            tags: ["science"]
        ),
        source(
            id: "ansa-sicilia",
            outlet: "ANSA – Sicilia (regionale)",
            region: .italy,
            url: "https://www.ansa.it/sicilia/notizie/sicilia_rss.xml",
            language: "it",
            tags: ["regional"],
            note: "Updated to canonical /sicilia/notizie/sicilia_rss.xml pattern."
        ),
        source(
            id: "ansa-sport-calcio",
            outlet: "ANSA – Sport Calcio",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/sport/calcio/calcio_rss.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "ansa-sport-generale",
            outlet: "ANSA – Sport (Generale)",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/sport/sport_rss.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "ansa-tecnologia",
            outlet: "ANSA – Tecnologia",
            region: .italy,
            url: "https://www.ansa.it/canale_tecnologia/notizie/tecnologia_rss.xml",
            language: "it",
            tags: ["technology"]
        ),
        source(
            id: "ansa-topnews",
            outlet: "ANSA – Top News",
            region: .italy,
            url: "https://www.ansa.it/sito/notizie/topnews/topnews_rss.xml",
            main: true,
            language: "it",
            tags: ["general", "country-pick"]
        ),
        // Removed in live validation (#90): every `corriere.it/rss/*`
        // feed is a frozen archive (homepage newest item 2024-05-13,
        // economia ~884 days stale, cronaca 28 days and dying).
        // Corriere retired its public RSS; no working alternate found.
        source(
            id: "fanpage",
            outlet: "Fanpage",
            region: .italy,
            url: "https://www.fanpage.it/feed/",
            language: "it",
            tags: ["digital"]
        ),
        source(
            id: "gazzetta-dello-sport",
            outlet: "Gazzetta dello Sport",
            region: .italy,
            // Replaced in live validation (#90): `/rss/homepage.xml`
            // is a frozen 2023-12 archive; the dynamic-feed endpoint
            // is the live one. Article bodies run short (live blogs,
            // pagelle), so the outlet is tracked as degraded.
            url: "https://www.gazzetta.it/dynamic-feed/rss/section/last.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "guardian-italy",
            outlet: "The Guardian – Italy",
            region: .italy,
            url: "https://www.theguardian.com/world/italy/rss",
            language: "en",
            tags: ["english"]
        ),
        source(
            id: "il-fatto-quotidiano",
            outlet: "Il Fatto Quotidiano",
            region: .italy,
            url: "https://www.ilfattoquotidiano.it/feed/",
            language: "it",
            tags: ["investigative"]
        ),
        // Removed in Phase 3 (#53): `il-foglio` returned HTTP 410 Gone
        // on 2026-06-26. Il Foglio deprecated the `/sezioni/112/rss`
        // pattern; no public-front-page RSS is currently documented.
        source(
            id: "il-giornale",
            outlet: "Il Giornale",
            region: .italy,
            url: "https://www.ilgiornale.it/feed.xml",
            language: "it",
            tags: ["general"]
        ),
        // Removed in Phase 3 (#53): `il-post` returned HTTP 403 on
        // 2026-06-26. Il Post serves their RSS only to whitelisted
        // user-agents; the MercuryRSSClient default UA is rejected
        // and no public alternate endpoint is documented.
        source(
            id: "ilsole24ore-finanza",
            outlet: "Il Sole 24 Ore – Finanza",
            region: .italy,
            url: "https://www.ilsole24ore.com/rss/finanza.xml",
            language: "it",
            tags: ["finance"]
        ),
        source(
            id: "ilsole24ore-italia",
            outlet: "Il Sole 24 Ore – Italia",
            region: .italy,
            url: "https://www.ilsole24ore.com/rss/italia.xml",
            main: true,
            language: "it",
            tags: ["economy", "country-pick"]
        ),
        source(
            id: "ilsole24ore-mondo",
            outlet: "Il Sole 24 Ore – Mondo",
            region: .italy,
            url: "https://www.ilsole24ore.com/rss/mondo.xml",
            language: "it",
            tags: ["world"]
        ),
        source(
            id: "internazionale",
            outlet: "Internazionale",
            region: .italy,
            url: "https://www.internazionale.it/sitemaps/rss.xml",
            language: "it",
            tags: ["weekly"]
        ),
        // Removed in Phase 3 (#53): `lastampa-copertina` returned HTTP
        // 403 on 2026-06-26. La Stampa's CDN rejects the Mercury
        // user-agent; no public alternate endpoint is documented.
        source(
            id: "libero-quotidiano",
            outlet: "Libero Quotidiano",
            region: .italy,
            url: "https://www.liberoquotidiano.it/rss.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "linkiesta",
            outlet: "Linkiesta",
            region: .italy,
            url: "https://www.linkiesta.it/it/feed/",
            language: "it",
            tags: ["opinion"]
        ),
        source(
            id: "milan-news",
            outlet: "Milan News",
            region: .italy,
            url: "https://www.milannews.it/rss/",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "panorama",
            outlet: "Panorama",
            region: .italy,
            url: "https://www.panorama.it/feeds/feed.rss",
            language: "it",
            tags: ["magazine"]
        ),
        source(
            id: "rai-portale-rss",
            outlet: "RAI News – Tutti gli aggiornamenti",
            region: .italy,
            // Replaced in live validation (#90): the rai.it
            // PublishingBlock feed only carries items linking to the
            // retired `rainews24.rai.it` host (every article 404s).
            // `rainews.it/rss/tutti` is the live RaiNews feed.
            url: "https://www.rainews.it/rss/tutti",
            main: true,
            language: "it",
            tags: ["public-broadcaster"],
            note: "Promoted to main outlet in Phase 3 after rainews-primopiano retirement."
        ),
        // Removed in Phase 3 (#53): `rai-radio-giornale` returned HTTP
        // 404 on 2026-06-26; RAI retired the `portaleAudio` RSS index.
        // Removed in Phase 3 (#53): `rai-tgr-piemonte` returned HTTP
        // 404 on 2026-06-26; the per-region TGR RSS surface was
        // deprecated. Keeping only the cross-region RAI feeds.
        // Removed in Phase 3 (#53): `rainews-primopiano` at `/rss.rss`
        // returned HTTP 404 on 2026-06-26 and no `rainews.it` RSS
        // surface is currently published. The `rai-portale-rss` entry
        // above (PublishingBlock UUID feed) remains and now carries
        // RAI's main-outlet role for Italy.
        source(
            id: "repubblica-cronaca",
            outlet: "La Repubblica – Cronaca",
            region: .italy,
            url: "https://www.repubblica.it/rss/cronaca/rss2.0.xml",
            language: "it",
            tags: ["general"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "repubblica-economia",
            outlet: "La Repubblica – Economia",
            region: .italy,
            url: "https://www.repubblica.it/rss/economia/rss2.0.xml",
            language: "it",
            tags: ["economy"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "repubblica-esteri",
            outlet: "La Repubblica – Esteri",
            region: .italy,
            url: "https://www.repubblica.it/rss/esteri/rss2.0.xml",
            language: "it",
            tags: ["world"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "repubblica-homepage",
            outlet: "La Repubblica – Homepage",
            region: .italy,
            url: "https://www.repubblica.it/rss/homepage/rss2.0.xml",
            main: true,
            language: "it",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "repubblica-politica",
            outlet: "La Repubblica – Politica",
            region: .italy,
            url: "https://www.repubblica.it/rss/politica/rss2.0.xml",
            language: "it",
            tags: ["politics"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "sky-tg24-homepage",
            outlet: "Sky TG24 – Homepage",
            region: .italy,
            // Replaced in Phase 3 (#53): all three per-section
            // `tg24.sky.it/rss/<section>.xml` URLs returned HTTP 404
            // on 2026-06-26. The aggregate homepage feed at
            // `tg24_homepage.xml` is live and covers the same daily
            // news mix.
            url: "https://tg24.sky.it/rss/tg24_homepage.xml",
            language: "it",
            tags: ["broadcast"]
        ),
        source(
            id: "tgcom24-economia",
            outlet: "TGCOM24 – Economia",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/economia.xml",
            language: "it",
            tags: ["economy"]
        ),
        source(
            id: "tgcom24-homepage",
            outlet: "TGCOM24 – Homepage",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/homepage.xml",
            main: true,
            language: "it",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "tgcom24-politica",
            outlet: "TGCOM24 – Politica",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/politica.xml",
            language: "it",
            tags: ["politics"]
        ),
        source(
            id: "tgcom24-spettacolo",
            outlet: "TGCOM24 – Spettacolo",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/spettacolo.xml",
            language: "it",
            tags: ["entertainment"]
        ),
        source(
            id: "tgcom24-sport",
            outlet: "TGCOM24 – Sport",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/sport.xml",
            language: "it",
            tags: ["sports"]
        ),
        source(
            id: "tgcom24-tgtech",
            outlet: "TGCOM24 – TGTech",
            region: .italy,
            url: "https://www.tgcom24.mediaset.it/rss/tgtech.xml",
            language: "it",
            tags: ["technology"]
        ),
        source(
            id: "the-local-italy",
            outlet: "The Local Italy",
            region: .italy,
            url: "https://feeds.thelocal.com/rss/it",
            language: "en",
            tags: ["english"]
        )
    ]

    // MARK: - Japan

    private static let japanSources: [RSSFeedSource] = [
        source(
            id: "asahi-headlines",
            outlet: "Asahi Shimbun – Headlines",
            region: .japan,
            // Upgraded to HTTPS in Phase 3 (#53). The legacy
            // `http://rss.asahi.com/` host required `insecureTransport`
            // and was rejected by MercuryRSSClient; the same path
            // resolves over HTTPS today.
            url: "https://rss.asahi.com/rss/asahi/newsheadlines.rdf",
            language: "ja",
            tags: ["general"],
            note: "HTTPS endpoint may be UA-gated; revisit if it stays 4xx in prod."
        ),
        // Removed in live validation (#90): `japan-times-top` at
        // `/feed/topstories/` is ~490 days stale; the live `/feed/`
        // alternate exists but article pages answer 403 to the app's
        // Safari UA (bot gate + paywall), so no body is extractable.
        // Japan Today below inherits the country-pick role.
        source(
            id: "japan-today",
            outlet: "Japan Today",
            region: .japan,
            url: "https://japantoday.com/feed",
            main: true,
            language: "en",
            tags: ["english", "digital", "country-pick"],
            note: "Promoted to main outlet in #90 after the Japan Times removal."
        ),
        // Removed in Phase 3 (#53): `kyodo-en` returned HTTP 404 on
        // 2026-06-26 (Kyodo's English RSS API retired in 2024).
        // Removed in Phase 3 (#53): `livedoor-top` returned HTTP 403
        // on 2026-06-26 (Livedoor blocks non-browser UAs).
        // Removed in Phase 3 (#53): `mainichi-en` returned HTML
        // (parseFailed) on 2026-06-26; the `etc/mailnews.rss` path now
        // serves the newsletter landing page.
        source(
            id: "newsonjapan",
            outlet: "News On Japan",
            region: .japan,
            url: "https://www.newsonjapan.com/rss/top.xml",
            language: "en",
            tags: ["english", "digital"]
        ),
        // Removed in Phase 3 (#53): `nhk-world-en` returned HTTP 404 on
        // 2026-06-26. NHK World migrated their RSS surface multiple
        // times in 2024-2026 and no public-facing English headline
        // RSS is currently documented.
    ]

    // MARK: - Netherlands

    // Phase 3 (#53): all four `feeds.nos.nl/<topic>` URLs were updated
    // from the legacy `<topic>` short paths (which all returned HTTP
    // 404 on 2026-06-26) to the canonical `nos<topic>` paths
    // documented by NOS. `nieuwsalgemeen` → `nosnieuwsalgemeen`,
    // `nieuwspolitiek` → `nosnieuwspolitiek`, `sportalgemeen` →
    // `nossportalgemeen`, `wereldnieuws` → `nosnieuwsbuitenland`.
    private static let netherlandsSources: [RSSFeedSource] = [
        source(
            id: "dutchnews-en",
            outlet: "DutchNews.nl (EN)",
            region: .netherlands,
            url: "https://www.dutchnews.nl/feed/",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "nos-algemeen",
            outlet: "NOS – Algemeen",
            region: .netherlands,
            url: "https://feeds.nos.nl/nosnieuwsalgemeen",
            main: true,
            language: "nl",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "nos-politiek",
            outlet: "NOS – Politiek",
            region: .netherlands,
            url: "https://feeds.nos.nl/nosnieuwspolitiek",
            language: "nl",
            tags: ["politics"]
        ),
        source(
            id: "nos-sport",
            outlet: "NOS – Sport",
            region: .netherlands,
            url: "https://feeds.nos.nl/nossportalgemeen",
            language: "nl",
            tags: ["sports"]
        ),
        source(
            id: "nos-wereld",
            outlet: "NOS – Wereld",
            region: .netherlands,
            url: "https://feeds.nos.nl/nosnieuwsbuitenland",
            language: "nl",
            tags: ["world"]
        ),
        source(
            id: "nrc-voorpagina",
            outlet: "NRC – Voorpagina",
            region: .netherlands,
            url: "https://www.nrc.nl/rss/",
            language: "nl",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        )
        // Removed in live validation (#90): `volkskrant` article pages
        // serve the DPG Media consent interstitial (an 8 KB JS shell
        // with no article body); the feed itself was already title-only.
    ]

    // MARK: - Norway

    private static let norwaySources: [RSSFeedSource] = [
        source(
            id: "aftenposten-forsiden",
            outlet: "Aftenposten – Forsiden",
            region: .norway,
            url: "https://www.aftenposten.no/rss",
            language: "no",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "dagbladet",
            outlet: "Dagbladet",
            region: .norway,
            url: "https://www.dagbladet.no/rss/",
            language: "no",
            tags: ["tabloid"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "nrk-norge",
            outlet: "NRK – Norge",
            region: .norway,
            url: "https://www.nrk.no/norge/toppsaker.rss",
            language: "no",
            tags: ["national"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "nrk-toppsaker",
            outlet: "NRK – Toppsaker",
            region: .norway,
            url: "https://www.nrk.no/toppsaker.rss",
            main: true,
            language: "no",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "nrk-urix",
            outlet: "NRK – Urix (utenriks)",
            region: .norway,
            url: "https://www.nrk.no/urix/toppsaker.rss",
            language: "no",
            tags: ["world"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "vg-forsiden",
            outlet: "VG – Forsiden",
            region: .norway,
            // Replaced in Phase 3 (#53): the legacy `/rss/feed/forsiden/`
            // path returned HTTP 404 on 2026-06-26. VG serves the same
            // front-page mix at the bare `/rss/feed/` endpoint today.
            url: "https://www.vg.no/rss/feed/",
            language: "no",
            tags: ["tabloid"]
        )
    ]

    // MARK: - Poland

    private static let polandSources: [RSSFeedSource] = [
        // Removed in Phase 3 (#53): `dziennik-pl` and `gazeta-prawna`
        // both failed TLS handshake on 2026-06-26 — their CDN
        // certificates do not chain to roots trusted by iOS/Sim today.
        // Removed in Phase 3 (#53): `pap-pl` returned HTML (parseFailed)
        // on 2026-06-26 — PAP's public `/rss.xml` is bot-gated and
        // serves a HTML interstitial. `rmf24` below is promoted to the
        // country-pick role.
        source(
            id: "newsweek-pl",
            outlet: "Newsweek Polska",
            region: .poland,
            url: "https://www.newsweek.pl/rss.xml",
            language: "pl",
            tags: ["weekly"]
        ),
        source(
            id: "rmf24",
            outlet: "RMF24",
            region: .poland,
            url: "https://www.rmf24.pl/feed",
            main: true,
            language: "pl",
            tags: ["radio", "country-pick"],
            note: "Promoted to country-pick in Phase 3 after PAP and Dziennik dropouts."
        )
        // Removed in Phase 3 (#53): `rzeczpospolita` returned HTTP 403
        // on 2026-06-26 (per-IP throttling).
        // Removed in Phase 3 (#53): `wirtualnemedia` failed App
        // Transport Security on 2026-06-26 — their `rss/` endpoint
        // redirects to an http:// URL the client rejects.
    ]

    // MARK: - Portugal

    private static let portugalSources: [RSSFeedSource] = [
        // Removed in Phase 3 (#53): `diario-noticias-pt` returned HTTP
        // 404 on 2026-06-26 (dn.pt no longer documents a public RSS
        // endpoint).
        source(
            id: "observador",
            outlet: "Observador",
            region: .portugal,
            url: "https://observador.pt/feed/",
            language: "pt",
            tags: ["digital"],
            note: "Endpoint to verify in Phase 3."
        ),
        // Removed in live validation (#90): `publico-ultimas` on
        // Feedburner is frozen at 2019-07; `publico.pt/rss` and
        // `feeds.publico.pt/rss/destaques` both return empty bodies.
        source(
            id: "rtp-noticias",
            outlet: "RTP Notícias",
            region: .portugal,
            // Replaced in Phase 3 (#53): `/noticias/index.rss` returned
            // HTTP 404 on 2026-06-26. RTP serves the same news mix at
            // `/noticias/rss` (no `index` infix) today.
            url: "https://www.rtp.pt/noticias/rss",
            main: true,
            language: "pt",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "the-portugal-news-en",
            outlet: "The Portugal News (EN)",
            region: .portugal,
            url: "https://www.theportugalnews.com/rss",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - Romania

    private static let romaniaSources: [RSSFeedSource] = [
        // Removed in live validation (#90): `agerpres` at `/rss/`
        // times out / answers 500; the only discoverable alternate is
        // an unofficial FiveFilters scrape proxy without dates.
        // Digi24 below inherits the country-pick role.
        source(
            id: "digi24",
            outlet: "Digi24",
            region: .romania,
            url: "https://www.digi24.ro/rss",
            main: true,
            language: "ro",
            tags: ["broadcast", "country-pick"],
            note: "Promoted to main outlet in #90 after the Agerpres removal."
        ),
        source(
            id: "hotnews-ro",
            outlet: "HotNews.ro",
            region: .romania,
            url: "https://www.hotnews.ro/rss",
            language: "ro",
            tags: ["digital"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "romania-insider-en",
            outlet: "Romania Insider (EN)",
            region: .romania,
            // Replaced in Phase 3 (#53): the `/rss.xml` path returned
            // HTTP 404 on 2026-06-26. Romania Insider's current
            // canonical Atom-style feed is served at `/feed`.
            url: "https://www.romania-insider.com/feed",
            language: "en",
            tags: ["english"]
        )
    ]

    // MARK: - Spain

    private static let spainSources: [RSSFeedSource] = [
        // Removed in Phase 3 (#53): `efe-english` returned HTML
        // (parseFailed) on 2026-06-26 — EFE's `/efe/english/4/rss`
        // path now serves the section landing page rather than RSS.
        source(
            id: "elconfidencial-espana",
            outlet: "El Confidencial – España",
            region: .spain,
            url: "https://rss.elconfidencial.com/espana/",
            language: "es",
            tags: ["investigative"]
        ),
        source(
            id: "eldiario-es",
            outlet: "elDiario.es",
            region: .spain,
            url: "https://www.eldiario.es/rss/",
            language: "es",
            tags: ["digital"]
        ),
        source(
            id: "elpais-portada",
            outlet: "EL PAÍS – Portada",
            region: .spain,
            url: "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada",
            main: true,
            language: "es",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "elperiodico-internacional",
            outlet: "El Periódico – Internacional",
            region: .spain,
            // Replaced in live validation (#90): the former
            // `rss_portada.xml` returns a valid channel with 0 items.
            // The per-section feeds are live; Internacional carries
            // the general-news wire.
            url: "https://www.elperiodico.com/es/rss/internacional/rss.xml",
            language: "es",
            tags: ["general"]
        ),
        source(
            id: "expansion-portada",
            outlet: "Expansión – Portada",
            region: .spain,
            url: "https://e00-expansion.uecdn.es/rss/portada.xml",
            language: "es",
            tags: ["economy"]
        ),
        source(
            id: "huffpost-es",
            outlet: "HuffPost España",
            region: .spain,
            url: "https://www.huffingtonpost.es/feeds/index.xml",
            language: "es",
            tags: ["digital"]
        ),
        // Removed in Phase 3 (#53): all three `rtve-*` feeds either
        // 301-redirected to an `http://` URL the client rejected
        // (`/rss/deportes.xml`, `/rss/economia.xml`) or returned HTTP
        // 404 (`/rss/noticias.xml`) on 2026-06-26. RTVE retired the
        // `/rss/<topic>.xml` pattern in favor of section-specific Atom
        // feeds we have not yet inventoried.
        source(
            id: "the-local-spain",
            outlet: "The Local Spain",
            region: .spain,
            url: "https://feeds.thelocal.com/rss/es",
            language: "en",
            tags: ["english"]
        )
    ]

    // MARK: - Sweden

    private static let swedenSources: [RSSFeedSource] = [
        source(
            id: "dn-senaste",
            outlet: "Dagens Nyheter – Senaste",
            region: .sweden,
            url: "https://www.dn.se/rss/",
            language: "sv",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "sr-ekot",
            outlet: "Sveriges Radio – Ekot",
            region: .sweden,
            // Replaced in live validation (#90): program/4540 is the
            // radio-broadcast rundown whose article links 404.
            // program/83 is the Ekot text-news feed with real articles.
            url: "https://api.sr.se/api/rss/program/83",
            language: "sv",
            tags: ["radio"]
        ),
        source(
            id: "svt-all",
            outlet: "SVT Nyheter – All",
            region: .sweden,
            url: "https://www.svt.se/nyheter/rss.xml",
            main: true,
            language: "sv",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "svt-sverige",
            outlet: "SVT Nyheter – Sverige",
            region: .sweden,
            url: "https://www.svt.se/nyheter/sverige/rss.xml",
            language: "sv",
            tags: ["national"]
        ),
        source(
            id: "svt-varlden",
            outlet: "SVT Nyheter – Världen",
            region: .sweden,
            url: "https://www.svt.se/nyheter/varlden/rss.xml",
            language: "sv",
            tags: ["world"]
        )
    ]

    // MARK: - Switzerland

    private static let switzerlandSources: [RSSFeedSource] = [
        source(
            id: "letemps",
            outlet: "Le Temps",
            region: .switzerland,
            url: "https://www.letemps.ch/articles.rss",
            language: "fr",
            tags: ["general"],
            note: "Paywalled summaries; endpoint to verify in Phase 3."
        ),
        // Removed in Phase 3 (#53): `rsi-notizie` returned HTTP 404 on
        // 2026-06-26 (RSI's `/news/feed` path is no longer published).
        // Removed in Phase 3 (#53): `rts-info` returned HTML
        // (parseFailed) on 2026-06-26 — the `?format=rss` query no
        // longer produces a feed response.
        source(
            id: "srf-international",
            outlet: "SRF – International",
            region: .switzerland,
            url: "https://www.srf.ch/news/bnf/rss/1922",
            language: "de",
            tags: ["world"],
            note: "Endpoint ID to verify in Phase 3."
        ),
        source(
            id: "srf-schweiz",
            outlet: "SRF – Schweiz",
            region: .switzerland,
            url: "https://www.srf.ch/news/bnf/rss/1646",
            main: true,
            language: "de",
            tags: ["general", "country-pick"],
            note: "Endpoint ID to verify in Phase 3."
        ),
        source(
            id: "srf-wirtschaft",
            outlet: "SRF – Wirtschaft",
            region: .switzerland,
            url: "https://www.srf.ch/news/bnf/rss/1926",
            language: "de",
            tags: ["economy"],
            note: "Endpoint ID to verify in Phase 3."
        ),
        // Removed in Phase 3 (#53): `swissinfo-en` returned HTTP 404 on
        // 2026-06-26. Swissinfo restructured their feeds; no
        // English-only public endpoint is currently documented.
    ]

    // MARK: - United Kingdom

    private static let unitedKingdomSources: [RSSFeedSource] = [
        source(
            id: "bbc-business",
            outlet: "BBC News – Business",
            region: .unitedKingdom,
            url: "https://feeds.bbci.co.uk/news/business/rss.xml",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "bbc-technology",
            outlet: "BBC News – Technology",
            region: .unitedKingdom,
            url: "https://feeds.bbci.co.uk/news/technology/rss.xml",
            language: "en",
            tags: ["technology"]
        ),
        source(
            id: "bbc-uk-frontpage",
            outlet: "BBC News – UK Front Page",
            region: .unitedKingdom,
            url: "https://feeds.bbci.co.uk/news/rss.xml",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "bbc-uk-politics",
            outlet: "BBC News – UK Politics",
            region: .unitedKingdom,
            url: "https://feeds.bbci.co.uk/news/politics/rss.xml",
            language: "en",
            tags: ["politics"]
        ),
        source(
            id: "dailymail-home",
            outlet: "Daily Mail – Home",
            region: .unitedKingdom,
            url: "https://www.dailymail.co.uk/home/index.rss",
            language: "en",
            tags: ["tabloid"]
        ),
        source(
            id: "ft-home",
            outlet: "Financial Times – Home",
            region: .unitedKingdom,
            url: "https://www.ft.com/?format=rss",
            language: "en",
            tags: ["economy"],
            note: "Paywalled feed: summaries only."
        ),
        source(
            id: "guardian-politics-uk",
            outlet: "The Guardian – Politics",
            region: .unitedKingdom,
            url: "https://www.theguardian.com/politics/rss",
            language: "en",
            tags: ["politics"]
        ),
        source(
            id: "guardian-uk",
            outlet: "The Guardian – UK",
            region: .unitedKingdom,
            url: "https://www.theguardian.com/uk/rss",
            language: "en",
            tags: ["general"]
        ),
        source(
            id: "guardian-world-uk",
            outlet: "The Guardian – World",
            region: .unitedKingdom,
            url: "https://www.theguardian.com/world/rss",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "independent",
            outlet: "The Independent",
            region: .unitedKingdom,
            url: "https://www.independent.co.uk/news/uk/rss",
            language: "en",
            tags: ["general"]
        ),
        // Removed in Phase 3 (#53): `reuters-uk` failed DNS lookup on
        // 2026-06-26 — `feeds.reuters.com` no longer resolves.
        // Reuters retired all Feedburner endpoints between 2020-2022
        // and has not published a replacement public RSS surface.
        source(
            id: "sky-news-home",
            outlet: "Sky News – Home",
            region: .unitedKingdom,
            url: "https://feeds.skynews.com/feeds/rss/home.xml",
            language: "en",
            tags: ["broadcast"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - United States

    private static let unitedStatesSources: [RSSFeedSource] = [
        // Removed in live validation (#90): `ap-google-proxy` items
        // link to news.google.com JS-redirect stubs with no extractable
        // article body, so enrichment always fails. AP publishes no
        // official RSS to swap in.
        source(
            id: "cnbc-top",
            outlet: "CNBC – US Top News",
            region: .unitedStates,
            url: "https://www.cnbc.com/id/100003114/device/rss/rss.html",
            language: "en",
            tags: ["economy"]
        ),
        // Removed in Phase 3 (#53): `cnn-top` was http-only and the
        // 2026-06-26 harness rejected it via `insecureTransport`.
        // CNN's `rss.cnn.com` host does not serve a valid HTTPS
        // certificate (issued for a different SAN) so we cannot
        // safely swap to https without a UA-specific override.
        source(
            id: "fox-news-latest",
            outlet: "Fox News – Latest",
            region: .unitedStates,
            url: "https://moxie.foxnews.com/google-publisher/latest.xml",
            language: "en",
            tags: ["broadcast"],
            note: "Endpoint redirected from feeds.foxnews.com/foxnews/latest in 2024+."
        ),
        source(
            id: "huffpost-world",
            outlet: "HuffPost – World News",
            region: .unitedStates,
            url: "https://www.huffpost.com/section/world-news/feed",
            language: "en",
            tags: ["digital", "world"]
        ),
        source(
            id: "latimes-world-nation",
            outlet: "LA Times – World & Nation",
            region: .unitedStates,
            url: "https://www.latimes.com/world-nation/rss2.0.xml",
            language: "en",
            tags: ["regional"]
        ),
        source(
            id: "npr-business",
            outlet: "NPR – Business",
            region: .unitedStates,
            url: "https://feeds.npr.org/1006/rss.xml",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "npr-top",
            outlet: "NPR – Top Stories",
            region: .unitedStates,
            url: "https://feeds.npr.org/1001/rss.xml",
            main: true,
            language: "en",
            tags: ["public-radio", "country-pick"]
        ),
        source(
            id: "npr-world",
            outlet: "NPR – World",
            region: .unitedStates,
            url: "https://feeds.npr.org/1004/rss.xml",
            language: "en",
            tags: ["world"]
        ),
        // Removed in live validation (#90): `nyt-top` and `nyt-world`
        // feeds are healthy, but nytimes.com article pages answer a
        // hard 403 block page to the app's Safari UA (verified with
        // both curl and URLSession), so no body is ever extractable.
        // NPR keeps the United States country-pick role.
        source(
            id: "politico-playbook",
            outlet: "Politico – Playbook",
            region: .unitedStates,
            url: "https://rss.politico.com/playbook.xml",
            language: "en",
            tags: ["politics"]
        ),
        // Removed in Phase 3 (#53): `reuters-top-legacy` failed DNS on
        // 2026-06-26 — `feeds.reuters.com` no longer resolves.
        // Removed in live validation (#90): `washingtonpost-world`
        // article pages are a ~1 MB JS shell whose visible body is a
        // ~900-char teaser behind a hard paywall.
        source(
            id: "wsj-world",
            outlet: "WSJ – World News",
            region: .unitedStates,
            // Replaced in live validation (#90): `feeds.a.dj.com` is
            // frozen at 2025-01. Dow Jones moved its public feeds to
            // `feeds.content.dowjones.io`; articles extract cleanly.
            url: "https://feeds.content.dowjones.io/public/rss/RSSWorldNews",
            language: "en",
            tags: ["economy", "world"]
        )
    ]

    // MARK: - Factory

    private static func source(
        id: String,
        outlet: String,
        region: RSSFeedRegion,
        url: String? = nil,
        main: Bool = false,
        language: String? = nil,
        tags: [String] = [],
        note: String? = nil
    ) -> RSSFeedSource {
        RSSFeedSource(
            id: id,
            outletName: outlet,
            region: region,
            feedURLString: url,
            isMainOutlet: main,
            languageCode: language,
            tags: tags,
            note: note
        )
    }
}
