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
//  harvested during Phase 1 (issue #50). Validation (Phase 3) is tracked as a
//  follow-up; some entries carry `note` callouts where the upstream is fragile.
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
        source(
            id: "brussels-times",
            outlet: "The Brussels Times",
            region: .belgium,
            url: "https://www.brusselstimes.com/feed",
            language: "en",
            tags: ["english", "general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "destandaard-nieuws",
            outlet: "De Standaard – Nieuws",
            region: .belgium,
            url: "https://www.standaard.be/rss/section/1f2838d4-99ea-49f0-9102-138784c7ea7c",
            language: "nl",
            tags: ["general"],
            note: "Section UUID to verify in Phase 3."
        ),
        source(
            id: "detijd-nieuws",
            outlet: "De Tijd – Nieuws",
            region: .belgium,
            url: "https://www.tijd.be/rss.xml",
            language: "nl",
            tags: ["economy"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "hln",
            outlet: "Het Laatste Nieuws",
            region: .belgium,
            url: "https://www.hln.be/rss.xml",
            language: "nl",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "lecho",
            outlet: "L'Echo – Économie",
            region: .belgium,
            url: "https://www.lecho.be/rss.xml",
            language: "fr",
            tags: ["economy"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "lesoir-une",
            outlet: "Le Soir – Une",
            region: .belgium,
            url: "https://www.lesoir.be/rss/section/0.xml",
            language: "fr",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
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
            url: "https://agenciabrasil.ebc.com.br/rss.xml",
            language: "pt",
            tags: ["wire"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "brasil-wire-en",
            outlet: "Brasil Wire (EN)",
            region: .brazil,
            url: "https://www.brasilwire.com/feed/",
            language: "en",
            tags: ["english", "analysis"]
        ),
        source(
            id: "ebc-portal",
            outlet: "Portal EBC",
            region: .brazil,
            url: "https://www.ebc.com.br/rss/feed.xml",
            language: "pt",
            tags: ["public-broadcaster"]
        ),
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
        source(
            id: "jornaldebrasilia",
            outlet: "Jornal de Brasília",
            region: .brazil,
            url: "https://jornaldebrasilia.com.br/feed/",
            language: "pt",
            tags: ["regional"]
        ),
        source(
            id: "r7-noticias",
            outlet: "R7 – Notícias",
            region: .brazil,
            url: "https://noticias.r7.com/feed.xml",
            language: "pt",
            tags: ["general"]
        ),
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
        source(
            id: "bta-bg",
            outlet: "BTA – Bulgaria (BG)",
            region: .bulgaria,
            url: "https://www.bta.bg/bg/news/rss",
            language: "bg",
            tags: ["wire"]
        ),
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
        source(
            id: "novinite-en",
            outlet: "Novinite – English",
            region: .bulgaria,
            url: "https://www.novinite.com/services/news_rdf.php",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - Croatia

    private static let croatiaSources: [RSSFeedSource] = [
        source(
            id: "hrt-eu",
            outlet: "HRT – EU",
            region: .croatia,
            url: "https://feed.hrt.hr/?rubrika=eu",
            language: "hr",
            tags: ["eu", "politics"]
        ),
        source(
            id: "hrt-gospodarstvo",
            outlet: "HRT – Gospodarstvo",
            region: .croatia,
            url: "https://feed.hrt.hr/?rubrika=Gospodarstvo",
            language: "hr",
            tags: ["economy"]
        ),
        source(
            id: "hrt-sport",
            outlet: "HRT – Sport",
            region: .croatia,
            url: "https://feed.hrt.hr/?feed=hrt-sport",
            language: "hr",
            tags: ["sports"]
        ),
        source(
            id: "hrt-vijesti",
            outlet: "HRT – Vijesti",
            region: .croatia,
            url: "https://feed.hrt.hr/",
            main: true,
            language: "hr",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "hrt-znanost-tehnologija",
            outlet: "HRT – Znanost i tehnologija",
            region: .croatia,
            url: "https://feed.hrt.hr/?rubrika=Znanost_i_tehnologija",
            language: "hr",
            tags: ["science", "technology"]
        )
    ]

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
            outlet: "DR Nyheder – Seneste",
            region: .denmark,
            url: "https://www.dr.dk/nyheder/service/feeds/seneste",
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
        source(
            id: "tv2-nyheder",
            outlet: "TV 2 – Nyheder",
            region: .denmark,
            url: "https://feeds.tv2.dk/nyheder_seneste/rss",
            language: "da",
            tags: ["broadcast"],
            note: "Endpoint to verify in Phase 3."
        )
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
            url: "https://yle.fi/uutiset/rss/v1/news.rss",
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
        source(
            id: "focus-online",
            outlet: "FOCUS Online",
            region: .germany,
            url: "https://rss.focus.de/fol/XML/rss_folnews.xml",
            language: "de",
            tags: ["magazine"]
        ),
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
        source(
            id: "amna-english",
            outlet: "AMNA – English",
            region: .greece,
            url: "https://www.amna.gr/rss/english.xml",
            language: "en",
            tags: ["wire", "english"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "ertnews",
            outlet: "ERT News",
            region: .greece,
            url: "https://www.ertnews.gr/feed/",
            language: "el",
            tags: ["public-broadcaster"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "kathimerini-en",
            outlet: "Kathimerini – English",
            region: .greece,
            url: "https://feeds.feedburner.com/ekathimerini",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        )
    ]

    // MARK: - Hungary

    private static let hungarySources: [RSSFeedSource] = [
        source(
            id: "abouthungary-en",
            outlet: "About Hungary (EN)",
            region: .hungary,
            url: "https://abouthungary.hu/rss.xml",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "hirado-mti",
            outlet: "Híradó (MTI/MTVA)",
            region: .hungary,
            url: "https://www.hirado.hu/rss/hirapi",
            main: true,
            language: "hu",
            tags: ["public-broadcaster", "country-pick"]
        ),
        source(
            id: "index-hu",
            outlet: "Index.hu",
            region: .hungary,
            url: "https://index.hu/24ora/rss",
            language: "hu",
            tags: ["digital"],
            note: "Endpoint to verify in Phase 3."
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
        source(
            id: "rte-business",
            outlet: "RTÉ News – Business",
            region: .ireland,
            url: "https://www.rte.ie/news/rss/business-headlines.xml",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "rte-gaa",
            outlet: "RTÉ – GAA",
            region: .ireland,
            url: "https://www.rte.ie/rss/gaa.xml",
            language: "en",
            tags: ["sports"]
        ),
        source(
            id: "rte-headlines",
            outlet: "RTÉ News – Headlines",
            region: .ireland,
            url: "https://www.rte.ie/news/rss/news-headlines.xml",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
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
            language: "en",
            tags: ["digital"]
        )
    ]

    // MARK: - Italy

    private static let italySources: [RSSFeedSource] = [
        source(
            id: "adnkronos-prima",
            outlet: "Adnkronos – Prima Pagina",
            region: .italy,
            url: "http://rss.adnkronos.com/RSS_PrimaPagina.xml",
            language: "it",
            tags: ["wire"],
            note: "HTTP-only endpoint; https variant to evaluate in Phase 3."
        ),
        source(
            id: "agi-cronaca",
            outlet: "AGI – Agenzia Italia (Top News)",
            region: .italy,
            url: "https://www.agi.it/feed/cronaca/rss",
            language: "it",
            tags: ["wire"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
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
        source(
            id: "ansa-english",
            outlet: "ANSA – English",
            region: .italy,
            url: "https://www.ansa.it/english/news/english_notizie.xml",
            language: "en",
            tags: ["english"]
        ),
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
        source(
            id: "corriere-cronaca",
            outlet: "Corriere della Sera – Cronaca",
            region: .italy,
            url: "https://www.corriere.it/rss/cronaca.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "corriere-economia",
            outlet: "Corriere della Sera – Economia",
            region: .italy,
            url: "https://www.corriere.it/rss/economia.xml",
            language: "it",
            tags: ["economy"]
        ),
        source(
            id: "corriere-esteri",
            outlet: "Corriere della Sera – Esteri",
            region: .italy,
            url: "https://www.corriere.it/rss/esteri.xml",
            language: "it",
            tags: ["world"]
        ),
        source(
            id: "corriere-homepage",
            outlet: "Corriere della Sera – Homepage",
            region: .italy,
            url: "https://www.corriere.it/rss/homepage.xml",
            main: true,
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "corriere-politica",
            outlet: "Corriere della Sera – Politica",
            region: .italy,
            url: "https://www.corriere.it/rss/politica.xml",
            language: "it",
            tags: ["politics"]
        ),
        source(
            id: "corriere-sport",
            outlet: "Corriere della Sera – Sport",
            region: .italy,
            url: "https://www.corriere.it/rss/sport.xml",
            language: "it",
            tags: ["sports"]
        ),
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
            url: "https://www.gazzetta.it/rss/homepage.xml",
            language: "it",
            tags: ["sports"],
            note: "Endpoint pattern to verify in Phase 3."
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
        source(
            id: "il-foglio",
            outlet: "Il Foglio",
            region: .italy,
            url: "https://www.ilfoglio.it/sezioni/112/rss",
            language: "it",
            tags: ["opinion"],
            note: "Section 112 assumed to be front page; verify in Phase 3."
        ),
        source(
            id: "il-giornale",
            outlet: "Il Giornale",
            region: .italy,
            url: "https://www.ilgiornale.it/feed.xml",
            language: "it",
            tags: ["general"]
        ),
        source(
            id: "il-post",
            outlet: "Il Post",
            region: .italy,
            url: "https://www.ilpost.it/feed/",
            language: "it",
            tags: ["explainer"]
        ),
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
        source(
            id: "lastampa-copertina",
            outlet: "La Stampa – Copertina",
            region: .italy,
            url: "https://www.lastampa.it/rss/copertina.xml",
            language: "it",
            tags: ["general"]
        ),
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
            outlet: "RAI News – Portale RSS",
            region: .italy,
            url: "https://www.rai.it/dl/portale/html/PublishingBlock-15c2c340-e282-473d-b944-661e818d667b-rss.xml",
            language: "it",
            tags: ["public-broadcaster"]
        ),
        source(
            id: "rai-radio-giornale",
            outlet: "RAI Radio – Giornale Radio",
            region: .italy,
            url: "https://www.rai.it/dl/portaleAudio/Giornale_Radio_index.rss",
            language: "it",
            tags: ["radio"]
        ),
        source(
            id: "rai-tgr-piemonte",
            outlet: "RAI TGR Piemonte",
            region: .italy,
            url: "https://www.rainews.it/tgr/rss/piemonte.xml",
            language: "it",
            tags: ["regional"]
        ),
        source(
            id: "rainews-primopiano",
            outlet: "RAI News 24 – Primo Piano",
            region: .italy,
            url: "https://www.rainews.it/rss.rss",
            main: true,
            language: "it",
            tags: ["public-broadcaster"]
        ),
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
            id: "sky-tg24-cronaca",
            outlet: "Sky TG24 – Cronaca",
            region: .italy,
            url: "https://tg24.sky.it/rss/cronaca.xml",
            language: "it",
            tags: ["general"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "sky-tg24-mondo",
            outlet: "Sky TG24 – Mondo",
            region: .italy,
            url: "https://tg24.sky.it/rss/mondo.xml",
            language: "it",
            tags: ["world"],
            note: "Endpoint pattern to verify in Phase 3."
        ),
        source(
            id: "sky-tg24-politica",
            outlet: "Sky TG24 – Politica",
            region: .italy,
            url: "https://tg24.sky.it/rss/politica.xml",
            language: "it",
            tags: ["politics"],
            note: "Endpoint pattern to verify in Phase 3."
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
            url: "http://rss.asahi.com/rss/asahi/newsheadlines.rdf",
            language: "ja",
            tags: ["general"],
            note: "HTTP-only endpoint; check https in Phase 3."
        ),
        source(
            id: "japan-times-top",
            outlet: "Japan Times – Top Stories",
            region: .japan,
            url: "https://www.japantimes.co.jp/feed/topstories/",
            main: true,
            language: "en",
            tags: ["english", "country-pick"]
        ),
        source(
            id: "japan-today",
            outlet: "Japan Today",
            region: .japan,
            url: "https://japantoday.com/feed",
            language: "en",
            tags: ["english", "digital"]
        ),
        source(
            id: "kyodo-en",
            outlet: "Kyodo News+ (EN)",
            region: .japan,
            url: "https://english.kyodonews.net/rss/all.xml",
            language: "en",
            tags: ["wire", "english"]
        ),
        source(
            id: "livedoor-top",
            outlet: "Livedoor News – Top",
            region: .japan,
            url: "https://news.livedoor.com/topics/rss/top.xml",
            language: "ja",
            tags: ["digital"]
        ),
        source(
            id: "mainichi-en",
            outlet: "The Mainichi (EN)",
            region: .japan,
            url: "https://mainichi.jp/rss/etc/mailnews.rss",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "newsonjapan",
            outlet: "News On Japan",
            region: .japan,
            url: "https://www.newsonjapan.com/rss/top.xml",
            language: "en",
            tags: ["english", "digital"]
        ),
        source(
            id: "nhk-world-en",
            outlet: "NHK World – Top Stories (EN)",
            region: .japan,
            url: "https://www3.nhk.or.jp/nhkworld/en/news/feeds/rss/news-en.xml",
            language: "en",
            tags: ["public-broadcaster", "english"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - Netherlands

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
            url: "https://feeds.nos.nl/nieuwsalgemeen",
            main: true,
            language: "nl",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "nos-politiek",
            outlet: "NOS – Politiek",
            region: .netherlands,
            url: "https://feeds.nos.nl/nieuwspolitiek",
            language: "nl",
            tags: ["politics"]
        ),
        source(
            id: "nos-sport",
            outlet: "NOS – Sport",
            region: .netherlands,
            url: "https://feeds.nos.nl/sportalgemeen",
            language: "nl",
            tags: ["sports"]
        ),
        source(
            id: "nos-wereld",
            outlet: "NOS – Wereld",
            region: .netherlands,
            url: "https://feeds.nos.nl/wereldnieuws",
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
        ),
        source(
            id: "volkskrant",
            outlet: "De Volkskrant",
            region: .netherlands,
            url: "https://www.volkskrant.nl/voorpagina/rss.xml",
            language: "nl",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        )
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
            url: "https://www.vg.no/rss/feed/forsiden/",
            language: "no",
            tags: ["tabloid"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - Poland

    private static let polandSources: [RSSFeedSource] = [
        source(
            id: "dziennik-pl",
            outlet: "Dziennik.pl",
            region: .poland,
            url: "https://rss.dziennik.pl/Dziennik-PL/",
            language: "pl",
            tags: ["general"]
        ),
        source(
            id: "gazeta-prawna",
            outlet: "Gazeta Prawna",
            region: .poland,
            url: "https://rss.gazetaprawna.pl/GazetaPrawna",
            language: "pl",
            tags: ["economy", "legal"]
        ),
        source(
            id: "newsweek-pl",
            outlet: "Newsweek Polska",
            region: .poland,
            url: "https://www.newsweek.pl/rss.xml",
            language: "pl",
            tags: ["weekly"]
        ),
        source(
            id: "pap-pl",
            outlet: "PAP – Polska Agencja Prasowa",
            region: .poland,
            url: "https://www.pap.pl/rss.xml",
            main: true,
            language: "pl",
            tags: ["wire", "country-pick"]
        ),
        source(
            id: "rmf24",
            outlet: "RMF24",
            region: .poland,
            url: "https://www.rmf24.pl/feed",
            language: "pl",
            tags: ["radio"]
        ),
        source(
            id: "rzeczpospolita",
            outlet: "Rzeczpospolita",
            region: .poland,
            url: "https://www.rp.pl/rss/1019",
            language: "pl",
            tags: ["general"]
        ),
        source(
            id: "wirtualnemedia",
            outlet: "Wirtualne Media",
            region: .poland,
            url: "https://www.wirtualnemedia.pl/rss/wirtualnemedia_rss.xml",
            language: "pl",
            tags: ["media-industry"]
        )
    ]

    // MARK: - Portugal

    private static let portugalSources: [RSSFeedSource] = [
        source(
            id: "diario-noticias-pt",
            outlet: "Diário de Notícias",
            region: .portugal,
            url: "https://www.dn.pt/rss",
            language: "pt",
            tags: ["general"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "observador",
            outlet: "Observador",
            region: .portugal,
            url: "https://observador.pt/feed/",
            language: "pt",
            tags: ["digital"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "publico-ultimas",
            outlet: "Público – Últimas",
            region: .portugal,
            url: "https://feeds.feedburner.com/PublicoUltimaHora",
            language: "pt",
            tags: ["general"],
            note: "Feedburner endpoint to verify in Phase 3."
        ),
        source(
            id: "rtp-noticias",
            outlet: "RTP Notícias",
            region: .portugal,
            url: "https://www.rtp.pt/noticias/index.rss",
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
        source(
            id: "agerpres",
            outlet: "Agerpres",
            region: .romania,
            url: "https://www.agerpres.ro/rss/",
            main: true,
            language: "ro",
            tags: ["wire", "country-pick"]
        ),
        source(
            id: "digi24",
            outlet: "Digi24",
            region: .romania,
            url: "https://www.digi24.ro/rss",
            language: "ro",
            tags: ["broadcast"],
            note: "Endpoint to verify in Phase 3."
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
            url: "https://www.romania-insider.com/rss.xml",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        )
    ]

    // MARK: - Spain

    private static let spainSources: [RSSFeedSource] = [
        source(
            id: "efe-english",
            outlet: "Agencia EFE – English",
            region: .spain,
            url: "https://www.efe.com/efe/english/4/rss",
            language: "en",
            tags: ["wire", "english"]
        ),
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
            id: "elperiodico-portada",
            outlet: "El Periódico – Portada",
            region: .spain,
            url: "https://www.elperiodico.com/es/rss/rss_portada.xml",
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
        source(
            id: "rtve-deportes",
            outlet: "RTVE – Deportes",
            region: .spain,
            url: "https://www.rtve.es/rss/deportes.xml",
            language: "es",
            tags: ["sports"]
        ),
        source(
            id: "rtve-economia",
            outlet: "RTVE – Economia",
            region: .spain,
            url: "https://www.rtve.es/rss/economia.xml",
            language: "es",
            tags: ["economy"]
        ),
        source(
            id: "rtve-noticias",
            outlet: "RTVE – Noticias",
            region: .spain,
            url: "https://www.rtve.es/rss/noticias.xml",
            language: "es",
            tags: ["public-broadcaster"]
        ),
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
            url: "https://api.sr.se/api/rss/program/4540",
            language: "sv",
            tags: ["radio"],
            note: "Endpoint to verify in Phase 3."
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
        source(
            id: "rsi-notizie",
            outlet: "RSI – Notizie",
            region: .switzerland,
            url: "https://www.rsi.ch/news/feed",
            language: "it",
            tags: ["public-broadcaster"],
            note: "Endpoint to verify in Phase 3."
        ),
        source(
            id: "rts-info",
            outlet: "RTS Info – Toute l'info",
            region: .switzerland,
            url: "https://www.rts.ch/info/?format=rss",
            language: "fr",
            tags: ["public-broadcaster"],
            note: "Endpoint to verify in Phase 3."
        ),
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
        source(
            id: "swissinfo-en",
            outlet: "Swissinfo (EN)",
            region: .switzerland,
            url: "https://www.swissinfo.ch/eng/latest/rss",
            language: "en",
            tags: ["english"],
            note: "Endpoint to verify in Phase 3."
        )
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
        source(
            id: "reuters-uk",
            outlet: "Reuters – UK",
            region: .unitedKingdom,
            url: "https://feeds.reuters.com/reuters/UKTopNews",
            language: "en",
            tags: ["wire"],
            note: "Legacy Feedburner endpoint; expected to be dead in Phase 3."
        ),
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
        source(
            id: "ap-google-proxy",
            outlet: "AP News – Top Headlines",
            region: .unitedStates,
            url: "https://news.google.com/rss/search?q=site%3Aapnews.com+when%3A1d&hl=en-US&gl=US&ceid=US:en",
            language: "en",
            tags: ["wire"],
            note: "AP no longer publishes official RSS; Google News proxy until Phase 3."
        ),
        source(
            id: "cnbc-top",
            outlet: "CNBC – US Top News",
            region: .unitedStates,
            url: "https://www.cnbc.com/id/100003114/device/rss/rss.html",
            language: "en",
            tags: ["economy"]
        ),
        source(
            id: "cnn-top",
            outlet: "CNN – Top Stories",
            region: .unitedStates,
            url: "http://rss.cnn.com/rss/edition.rss",
            language: "en",
            tags: ["broadcast"]
        ),
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
        source(
            id: "nyt-top",
            outlet: "NYT – Top Stories",
            region: .unitedStates,
            url: "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
            main: true,
            language: "en",
            tags: ["general", "country-pick"]
        ),
        source(
            id: "nyt-world",
            outlet: "NYT – World",
            region: .unitedStates,
            url: "https://rss.nytimes.com/services/xml/rss/nyt/World.xml",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "politico-playbook",
            outlet: "Politico – Playbook",
            region: .unitedStates,
            url: "https://rss.politico.com/playbook.xml",
            language: "en",
            tags: ["politics"]
        ),
        source(
            id: "reuters-top-legacy",
            outlet: "Reuters – Top News (legacy)",
            region: .unitedStates,
            url: "https://feeds.reuters.com/reuters/topNews",
            language: "en",
            tags: ["wire"],
            note: "Reuters retired most public RSS in 2020-2022; expected to fail."
        ),
        source(
            id: "washingtonpost-world",
            outlet: "Washington Post – World",
            region: .unitedStates,
            url: "http://feeds.washingtonpost.com/rss/world",
            language: "en",
            tags: ["world"]
        ),
        source(
            id: "wsj-world",
            outlet: "WSJ – World News",
            region: .unitedStates,
            url: "https://feeds.a.dj.com/rss/RSSWorldNews.xml",
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
