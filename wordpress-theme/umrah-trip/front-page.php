<?php
get_header();
$apk = esc_url(ut_opt('ut_apk_url', 'https://github.com/semrush733-ux/umrah-trip/releases/download/latest/UmrahTrip.apk'));
$ipa = esc_url(ut_opt('ut_ipa_url', 'https://github.com/semrush733-ux/umrah-trip/releases/download/latest/UmrahTrip-unsigned.ipa'));
$android_svg = '<svg viewBox="0 0 24 24"><path d="M17.6 9.48l1.84-3.18a.38.38 0 0 0-.66-.38l-1.86 3.22a11.3 11.3 0 0 0-9.84 0L5.22 5.92a.38.38 0 0 0-.66.38L6.4 9.48A10.76 10.76 0 0 0 1 18h22a10.76 10.76 0 0 0-5.4-8.52zM7 15.25A1.25 1.25 0 1 1 8.25 14 1.25 1.25 0 0 1 7 15.25zm10 0A1.25 1.25 0 1 1 18.25 14 1.25 1.25 0 0 1 17 15.25z"/></svg>';
$apple_svg = '<svg viewBox="0 0 24 24"><path d="M16.37 12.65c0-2.37 1.94-3.5 2.03-3.56a4.36 4.36 0 0 0-3.44-1.86c-1.46-.15-2.85.86-3.59.86s-1.88-.84-3.1-.82A4.58 4.58 0 0 0 4.4 9.6c-1.65 2.86-.42 7.1 1.18 9.42.78 1.14 1.72 2.42 2.95 2.37s1.63-.76 3.06-.76 1.83.76 3.08.74 2.08-1.16 2.86-2.3a10.2 10.2 0 0 0 1.29-2.65 4.14 4.14 0 0 1-2.45-3.77zM14 5.67A4.2 4.2 0 0 0 15 2.6a4.27 4.27 0 0 0-2.79 1.44 4 4 0 0 0-1 3 3.54 3.54 0 0 0 2.79-1.37z"/></svg>';
?>

<section class="ut-hero">
  <div class="ut-container">
    <div class="ut-hero-copy">
      <span class="ut-kicker">🕋 57 Ziyarat &amp; Travel Destinations</span>
      <h1>Your Smart <span class="gold">Umrah</span> &amp;<br>Ziyarat Companion</h1>
      <p class="ut-sub">Discover verified holy sites, navigate with one tap, plan every day of your journey, and keep your travel memories — even offline. English · اردو · العربية</p>
      <div class="ut-btns">
        <a class="ut-btn ut-btn-gold" href="<?php echo $apk; ?>" download><?php echo $android_svg; ?> Download APK</a>
        <a class="ut-btn ut-btn-outline" href="<?php echo $ipa; ?>" download><?php echo $apple_svg; ?> Download IPA</a>
      </div>
      <p class="ut-note">Android: install directly. iPhone: sideload via AltStore / Sideloadly.</p>
      <div class="ut-stats">
        <div class="ut-stat"><b>57</b><span>Destinations</span></div>
        <div class="ut-stat"><b>7</b><span>Regions of KSA</span></div>
        <div class="ut-stat"><b>3</b><span>Languages + RTL</span></div>
        <div class="ut-stat"><b>100%</b><span>Offline-first</span></div>
      </div>
    </div>
    <div class="ut-phone-wrap">
      <div class="ut-phone"><div class="ut-screen">
        <img src="<?php echo ut_asset('logo.png'); ?>" alt="Umrah Trip app">
        <div class="t1">UMRAH TRIP</div>
        <div class="t2">Your Smart Umrah &amp; Ziyarat Companion</div>
        <div class="bar"></div>
      </div></div>
    </div>
  </div>
</section>

<section class="ut-section" id="features">
  <div class="ut-container">
    <h2>Everything a pilgrim needs</h2>
    <div class="ut-gold-line"></div>
    <p class="ut-lede">Built for the blessed journey — accurate information, honest navigation, and tools that work without internet.</p>
    <div class="ut-grid">
      <div class="ut-card ut-reveal"><div class="ut-ico">🕋</div><h3>57 Verified Destinations</h3><p>Makkah, Madinah, Jeddah, Taif, Riyadh, AlUla &amp; Eastern Province — authentic history with references, Urdu &amp; Arabic names, verified GPS.</p></div>
      <div class="ut-card ut-reveal"><div class="ut-ico">🧭</div><h3>One-Tap Navigation</h3><p>Live GPS position, real distances, and turn-by-turn directions to every ziyarat via Google or Apple Maps.</p></div>
      <div class="ut-card ut-reveal"><div class="ut-ico">📅</div><h3>Date-wise Trip Planner</h3><p>Plan each day, set visit times, drag to reorder stops, and get a smart visiting order for the whole day.</p></div>
      <div class="ut-card ut-reveal"><div class="ut-ico">✅</div><h3>Visited Tracking</h3><p>Mark places visited, GPS check-in, personal notes — your complete travel memories, saved forever.</p></div>
      <div class="ut-card ut-reveal"><div class="ut-ico">📖</div><h3>Umrah Guide</h3><p>Ihram, Tawaf and Sa'i step-by-step with authentic references, plus official Nusuk permit links for the Rawdah.</p></div>
      <div class="ut-card ut-reveal"><div class="ut-ico">📴</div><h3>Offline-First</h3><p>All destination details, your itinerary, visited status and notes work with no internet — made for the Haramain crowds.</p></div>
    </div>
  </div>
</section>

<section class="ut-section" id="pairing">
  <div class="ut-container">
    <div class="ut-pairing ut-reveal">
      <div class="ut-heart">❤️</div>
      <div>
        <h3>Couple Pairing — <span class="gold">travel together, stay together</span></h3>
        <p>Link two phones with one security code. See each other's live location pin on the map, know which ziyarat each of you has completed — and which you did <strong>together</strong> — and share camera photos privately between your two phones.</p>
        <span class="ut-code">AB3K7M</span>
      </div>
    </div>
  </div>
</section>

<section class="ut-section" id="download">
  <div class="ut-container">
    <div class="ut-download ut-reveal">
      <h2>Get Umrah Trip now</h2>
      <div class="ut-gold-line"></div>
      <p>Free download — latest build, updated automatically.</p>
      <div class="ut-btns">
        <a class="ut-btn ut-btn-gold" href="<?php echo $apk; ?>" download><?php echo $android_svg; ?> Android APK</a>
        <a class="ut-btn ut-btn-outline" href="<?php echo $ipa; ?>" download><?php echo $apple_svg; ?> iPhone IPA</a>
      </div>
      <p class="mini">APK: open the file and install (allow "unknown sources" if asked). IPA: sideload with AltStore or Sideloadly.</p>
    </div>
  </div>
</section>

<section class="ut-section ut-sponsor" id="sponsor">
  <div class="ut-container">
    <img class="ut-reveal" src="<?php echo ut_asset('sponsor.png'); ?>" alt="<?php echo esc_attr(ut_opt('ut_sponsor', 'Bin-Mukhtar Travels')); ?>">
    <p class="ut-sp-label">Sponsored by</p>
    <h2><?php echo esc_html(ut_opt('ut_sponsor', 'Bin-Mukhtar Travels')); ?></h2>
    <div class="ut-gold-line"></div>
    <p class="ut-lede"><?php echo esc_html(ut_opt('ut_sponsor_txt', 'Serving pilgrims with Umrah travel arrangements, guidance and care throughout their blessed journey.')); ?></p>
  </div>
</section>

<?php
$q = new WP_Query(['posts_per_page' => 3]);
if ($q->have_posts()) : ?>
<section class="ut-section">
  <div class="ut-container">
    <h2>Latest from the blog</h2>
    <div class="ut-gold-line"></div>
    <div class="ut-grid">
      <?php while ($q->have_posts()) : $q->the_post(); ?>
      <div class="ut-card ut-reveal">
        <h3><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
        <p><?php echo esc_html(wp_trim_words(get_the_excerpt(), 22)); ?></p>
      </div>
      <?php endwhile; wp_reset_postdata(); ?>
    </div>
  </div>
</section>
<?php endif; ?>

<?php get_footer(); ?>
