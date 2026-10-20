<?php get_header(); ?>

<section class="ut-hero" id="download">
  <img class="ut-hero-logo" src="<?php echo ut_asset('logo.png'); ?>" alt="Umrah Trip">
  <h1>UMRAH TRIP</h1>
  <p class="ut-sub">Your Smart Umrah &amp; Ziyarat Companion</p>
  <div class="ut-btns">
    <a class="ut-btn ut-btn-gold" href="<?php echo esc_url(ut_opt('ut_apk_url', 'https://github.com/semrush733-ux/umrah-trip/releases/latest')); ?>">⬇ Android APK</a>
    <a class="ut-btn ut-btn-outline" href="<?php echo esc_url(ut_opt('ut_ipa_url', 'https://github.com/semrush733-ux/umrah-trip/releases/latest')); ?>">⬇ iPhone IPA</a>
  </div>
  <p class="ut-note">56 ziyarat &amp; travel destinations · offline-first · English / اردو / العربية</p>
</section>

<section class="ut-section" id="features">
  <div class="ut-container">
    <h2>Everything a pilgrim needs</h2>
    <div class="ut-gold-line"></div>
    <div class="ut-grid">
      <div class="ut-card"><div class="ut-ico">🕋</div><h3>56 Verified Destinations</h3><p>Makkah, Madinah, Jeddah, Taif, Riyadh, AlUla &amp; Eastern Province — history with authentic references, Urdu &amp; Arabic names.</p></div>
      <div class="ut-card"><div class="ut-ico">🧭</div><h3>One-Tap Navigation</h3><p>Live GPS, distances, and turn-by-turn directions to every ziyarat via Google or Apple Maps.</p></div>
      <div class="ut-card"><div class="ut-ico">📅</div><h3>Date-wise Trip Planner</h3><p>Plan every day of your journey, reorder stops, set times, and get the best visiting order.</p></div>
      <div class="ut-card"><div class="ut-ico">✅</div><h3>Visited Tracking</h3><p>Mark places visited, check in by GPS, keep notes — your complete travel memories.</p></div>
      <div class="ut-card"><div class="ut-ico">❤️</div><h3>Couple Pairing</h3><p>Link two phones with one security code — share live location and see each other's completed ziyarat.</p></div>
      <div class="ut-card"><div class="ut-ico">📖</div><h3>Umrah Guide</h3><p>Ihram, Tawaf, Sa'i step-by-step with references, plus official Nusuk permit links for the Rawdah.</p></div>
    </div>
  </div>
</section>

<section class="ut-section ut-sponsor" id="sponsor">
  <div class="ut-container">
    <img src="<?php echo ut_asset('sponsor.png'); ?>" alt="<?php echo esc_attr(ut_opt('ut_sponsor', 'Bin-Mukhtar Travels')); ?>">
    <p class="ut-sp-label">Sponsored by</p>
    <h2><?php echo esc_html(ut_opt('ut_sponsor', 'Bin-Mukhtar Travels')); ?></h2>
    <div class="ut-gold-line"></div>
    <p class="ut-lede"><?php echo esc_html(ut_opt('ut_sponsor_txt', 'Serving pilgrims with Umrah travel arrangements, guidance and care throughout their blessed journey.')); ?></p>
  </div>
</section>

<?php
// Latest posts (optional blog section) — appears only if posts exist.
$q = new WP_Query(['posts_per_page' => 3]);
if ($q->have_posts()) : ?>
<section class="ut-section">
  <div class="ut-container">
    <h2>Latest from the blog</h2>
    <div class="ut-gold-line"></div>
    <div class="ut-grid">
      <?php while ($q->have_posts()) : $q->the_post(); ?>
      <div class="ut-card">
        <h3><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h3>
        <p><?php echo esc_html(wp_trim_words(get_the_excerpt(), 22)); ?></p>
      </div>
      <?php endwhile; wp_reset_postdata(); ?>
    </div>
  </div>
</section>
<?php endif; ?>

<?php get_footer(); ?>
