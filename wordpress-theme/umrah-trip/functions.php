<?php
/**
 * Umrah Trip theme — lightweight starter by BWP Experts.
 */

if (!defined('ABSPATH')) exit;

add_action('after_setup_theme', function () {
    add_theme_support('title-tag');
    add_theme_support('post-thumbnails');
    add_theme_support('custom-logo', ['height' => 96, 'width' => 96]);
    register_nav_menus(['primary' => __('Primary Menu', 'umrah-trip')]);
});

add_action('wp_enqueue_scripts', function () {
    wp_enqueue_style('umrah-trip', get_stylesheet_uri(), [], '1.0.0');
});

/** Customizer: app download links + sponsor text (easy to change later). */
add_action('customize_register', function ($wp_customize) {
    $wp_customize->add_section('ut_app', ['title' => 'Umrah Trip App', 'priority' => 30]);

    $fields = [
        'ut_apk_url'    => ['label' => 'Android APK download URL', 'default' => 'https://github.com/semrush733-ux/umrah-trip/releases/latest'],
        'ut_ipa_url'    => ['label' => 'iOS IPA download URL', 'default' => 'https://github.com/semrush733-ux/umrah-trip/releases/latest'],
        'ut_sponsor'    => ['label' => 'Sponsor name', 'default' => 'Bin-Mukhtar Travels'],
        'ut_sponsor_txt'=> ['label' => 'Sponsor description', 'default' => 'Serving pilgrims with Umrah travel arrangements, guidance and care throughout their blessed journey.'],
    ];
    foreach ($fields as $id => $f) {
        $wp_customize->add_setting($id, ['default' => $f['default'], 'sanitize_callback' => 'wp_kses_post']);
        $wp_customize->add_control($id, ['label' => $f['label'], 'section' => 'ut_app', 'type' => 'text']);
    }
});

function ut_opt($id, $default = '') {
    $v = get_theme_mod($id, $default);
    return $v !== '' ? $v : $default;
}

function ut_asset($file) {
    return esc_url(get_template_directory_uri() . '/assets/' . $file);
}
