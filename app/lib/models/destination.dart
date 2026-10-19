class Destination {
  final String id;
  final String region;
  final String nameEn;
  final String nameAr;
  final String nameUr;
  final String nameRoman;
  final List<String> aliases;
  final List<String> categories;
  final double lat;
  final double lng;
  final String? placeQuery;
  final bool verified;
  final String? sourceUrl;
  final String? lastVerified;
  final String summaryEn;
  final String summaryRoman;
  final String significance;
  final List<String> historyRefs;
  final num? entryFee; // null = unknown/unverified; 0 = free
  final bool feeVerified;
  final String? openingHours;
  final bool hoursVerified;
  final int visitDurationMin;
  final String? bestTime;
  final List<String> tips;
  final String? accessibility;
  final String? restrictions;
  final List<String> nearby;

  const Destination({
    required this.id,
    required this.region,
    required this.nameEn,
    required this.nameAr,
    required this.nameUr,
    required this.nameRoman,
    required this.aliases,
    required this.categories,
    required this.lat,
    required this.lng,
    this.placeQuery,
    required this.verified,
    this.sourceUrl,
    this.lastVerified,
    required this.summaryEn,
    required this.summaryRoman,
    required this.significance,
    required this.historyRefs,
    this.entryFee,
    required this.feeVerified,
    this.openingHours,
    required this.hoursVerified,
    required this.visitDurationMin,
    this.bestTime,
    required this.tips,
    this.accessibility,
    this.restrictions,
    required this.nearby,
  });

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'] as String,
        region: j['region'] as String,
        nameEn: j['name_en'] as String,
        nameAr: j['name_ar'] as String,
        nameUr: j['name_ur'] as String,
        nameRoman: j['name_roman'] as String,
        aliases: List<String>.from(j['aliases'] ?? const []),
        categories: List<String>.from(j['categories'] ?? const []),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        placeQuery: j['place_query'] as String?,
        verified: j['verified'] == true,
        sourceUrl: j['source_url'] as String?,
        lastVerified: j['last_verified'] as String?,
        summaryEn: j['summary_en'] as String? ?? '',
        summaryRoman: j['summary_roman'] as String? ?? '',
        significance: j['significance'] as String? ?? '',
        historyRefs: List<String>.from(j['history_refs'] ?? const []),
        entryFee: j['entry_fee'] as num?,
        feeVerified: j['fee_verified'] == true,
        openingHours: j['opening_hours'] as String?,
        hoursVerified: j['hours_verified'] == true,
        visitDurationMin: (j['visit_duration_min'] as num?)?.toInt() ?? 30,
        bestTime: j['best_time'] as String?,
        tips: List<String>.from(j['tips'] ?? const []),
        accessibility: j['accessibility'] as String?,
        restrictions: j['restrictions'] as String?,
        nearby: List<String>.from(j['nearby'] ?? const []),
      );

  bool get isFreeVerified => entryFee == 0 && feeVerified;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool hit(String s) => s.toLowerCase().contains(q);
    return hit(nameEn) ||
        hit(nameAr) ||
        hit(nameUr) ||
        hit(nameRoman) ||
        aliases.any(hit);
  }
}
