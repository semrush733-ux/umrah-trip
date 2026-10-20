<!doctype html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo('charset'); ?>">
<meta name="viewport" content="width=device-width, initial-scale=1">
<?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<header class="ut-header">
  <div class="ut-container">
    <img class="ut-logo" src="<?php echo ut_asset('logo.png'); ?>" alt="<?php bloginfo('name'); ?>">
    <div>
      <span class="ut-site-title"><?php bloginfo('name'); ?></span>
      <span class="ut-tagline">Your Smart Umrah &amp; Ziyarat Companion</span>
    </div>
    <nav>
      <?php
      if (has_nav_menu('primary')) {
          wp_nav_menu(['theme_location' => 'primary', 'container' => false, 'items_wrap' => '%3$s', 'fallback_cb' => false]);
      } else {
          echo '<a href="' . esc_url(home_url('/')) . '">Home</a>';
          echo '<a href="#features">Features</a>';
          echo '<a href="#download">Download</a>';
          echo '<a href="#sponsor">Sponsor</a>';
      }
      ?>
    </nav>
  </div>
</header>
