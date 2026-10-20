<?php
/**
 * Plugin Name: BWP Umrah Pair
 * Description: Umrah Trip app backend — couple pairing (code / QR / same-WiFi), live-location + visited sync, shared photos, plus the app admin panel: WhatsApp number, packages, announcements, extra destinations and the AI assistant proxy. REST namespace: umrah-pair/v1.
 * Version: 1.1.0
 * Author: BWP Experts
 * Author URI: https://bwpexperts.com
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) exit;

define('BWP_UMRAH_PAIR_VERSION', '1.1.0');
define('BWP_UMRAH_PAIR_MAX_PHOTO_B64', 1300000); // ~975 KB binary
define('BWP_UMRAH_PAIR_MAX_PHOTOS', 60);
define('BWP_UMRAH_PAIR_TTL_DAYS', 60);

register_activation_hook(__FILE__, 'bwp_umrah_pair_install');
add_action('plugins_loaded', function () {
    if (get_option('bwp_umrah_pair_db') !== BWP_UMRAH_PAIR_VERSION) bwp_umrah_pair_install();
});

function bwp_umrah_pair_table() {
    global $wpdb;
    return $wpdb->prefix . 'bwp_umrah_pairs';
}

function bwp_umrah_pair_install() {
    global $wpdb;
    $table = bwp_umrah_pair_table();
    $charset = $wpdb->get_charset_collate();
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta("CREATE TABLE $table (
        code VARCHAR(8) NOT NULL,
        created BIGINT UNSIGNED NOT NULL,
        updated BIGINT UNSIGNED NOT NULL,
        members LONGTEXT NOT NULL,
        photos LONGTEXT NOT NULL,
        PRIMARY KEY (code)
    ) $charset;");
    update_option('bwp_umrah_pair_db', BWP_UMRAH_PAIR_VERSION);
}

// ---------------------------------------------------------------- helpers

function bwp_up_now() { return time(); }

function bwp_up_json($data, $code = 200) {
    return new WP_REST_Response(array_merge(['ok' => $code === 200], $data), $code);
}

function bwp_up_err($msg, $code = 400) {
    return new WP_REST_Response(['ok' => false, 'error' => $msg], $code);
}

function bwp_up_code() {
    $alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    $out = '';
    for ($i = 0; $i < 6; $i++) $out .= $alphabet[random_int(0, strlen($alphabet) - 1)];
    return $out;
}

function bwp_up_load($code) {
    global $wpdb;
    $row = $wpdb->get_row($wpdb->prepare(
        'SELECT * FROM ' . bwp_umrah_pair_table() . ' WHERE code = %s', $code
    ), ARRAY_A);
    if (!$row) return null;
    $row['members'] = json_decode($row['members'], true) ?: [];
    $row['photos']  = json_decode($row['photos'], true) ?: [];
    return $row;
}

function bwp_up_save($code, $members, $photos, $insert = false) {
    global $wpdb;
    $data = [
        'updated' => bwp_up_now(),
        'members' => wp_json_encode($members),
        'photos'  => wp_json_encode($photos),
    ];
    if ($insert) {
        $data['code'] = $code;
        $data['created'] = bwp_up_now();
        return (bool) $wpdb->insert(bwp_umrah_pair_table(), $data);
    }
    return $wpdb->update(bwp_umrah_pair_table(), $data, ['code' => $code]) !== false;
}

function bwp_up_gc() { // light garbage collection of stale pairs
    global $wpdb;
    if (get_transient('bwp_up_gc')) return;
    set_transient('bwp_up_gc', 1, DAY_IN_SECONDS);
    $cutoff = bwp_up_now() - BWP_UMRAH_PAIR_TTL_DAYS * DAY_IN_SECONDS;
    $wpdb->query($wpdb->prepare(
        'DELETE FROM ' . bwp_umrah_pair_table() . ' WHERE updated < %d', $cutoff
    ));
}

function bwp_up_rate_limited($bucket, $limit, $window) {
    $ip = isset($_SERVER['REMOTE_ADDR']) ? preg_replace('/[^0-9a-fA-F:.]/', '', $_SERVER['REMOTE_ADDR']) : 'x';
    $key = 'bwp_up_rl_' . md5($bucket . '|' . $ip);
    $n = (int) get_transient($key);
    if ($n >= $limit) return true;
    set_transient($key, $n + 1, $window);
    return false;
}

function bwp_up_auth($pair, $token) {
    if (!$pair || !$token) return null;
    foreach ($pair['members'] as $tkn => $m) {
        if (hash_equals($tkn, $token)) return $tkn;
    }
    return null;
}

function bwp_up_sanitize_name($name) {
    $name = sanitize_text_field((string) $name);
    $name = mb_substr($name, 0, 30);
    return $name !== '' ? $name : 'Pilgrim';
}

// ---------------------------------------------------------------- routes

add_action('rest_api_init', function () {
    $ns = 'umrah-pair/v1';
    $pub = ['permission_callback' => '__return_true'];

    register_rest_route($ns, '/create', $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_create']);
    register_rest_route($ns, '/join',   $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_join']);
    register_rest_route($ns, '/nearby', $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_nearby']);
    register_rest_route($ns, '/sync',   $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_sync']);
    register_rest_route($ns, '/photo',  $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_photo']);
    register_rest_route($ns, '/unpair', $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_unpair']);
    register_rest_route($ns, '/config',       $pub + ['methods' => 'GET',  'callback' => 'bwp_up_route_config']);
    register_rest_route($ns, '/destinations', $pub + ['methods' => 'GET',  'callback' => 'bwp_up_route_destinations']);
    register_rest_route($ns, '/ai',           $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_ai']);
});

/**
 * Same-WiFi pairing: both phones POST /nearby within 2 minutes from the same
 * public IP. First caller creates a room; the second (different token, same
 * IP) joins it automatically.
 */
function bwp_up_route_nearby(WP_REST_Request $req) {
    if (bwp_up_rate_limited('nearby', 30, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $name = bwp_up_sanitize_name($req->get_param('name'));
    $ip = isset($_SERVER['REMOTE_ADDR']) ? preg_replace('/[^0-9a-fA-F:.]/', '', $_SERVER['REMOTE_ADDR']) : 'x';
    $key = 'bwp_up_nearby_' . md5($ip);

    $pending = get_transient($key);
    if (is_array($pending) && !empty($pending['code'])) {
        $pair = bwp_up_load($pending['code']);
        if ($pair && count($pair['members']) < 2) {
            $token = wp_generate_password(32, false, false);
            $pair['members'][$token] = [
                'name' => $name, 'last_seen' => bwp_up_now(),
                'lat' => null, 'lng' => null, 'acc' => null, 'loc_at' => 0,
                'sharing' => false, 'visits' => new stdClass(),
            ];
            bwp_up_save($pending['code'], $pair['members'], $pair['photos']);
            delete_transient($key);
            return bwp_up_json(['code' => $pending['code'], 'token' => $token, 'created' => false, 'members' => 2]);
        }
        delete_transient($key);
    }

    // Create a fresh room and park it for this IP for 2 minutes.
    $token = wp_generate_password(32, false, false);
    for ($try = 0; $try < 5; $try++) {
        $code = bwp_up_code();
        if (bwp_up_load($code)) continue;
        $members = [$token => [
            'name' => $name, 'last_seen' => bwp_up_now(),
            'lat' => null, 'lng' => null, 'acc' => null, 'loc_at' => 0,
            'sharing' => false, 'visits' => new stdClass(),
        ]];
        if (bwp_up_save($code, $members, [], true)) {
            set_transient($key, ['code' => $code], 2 * MINUTE_IN_SECONDS);
            return bwp_up_json(['code' => $code, 'token' => $token, 'created' => true, 'members' => 1]);
        }
    }
    return bwp_up_err('Could not create pair, try again', 500);
}

// ---------------------------------------------------------------- app config / admin

function bwp_up_settings() {
    $defaults = [
        'whatsapp' => '',
        'packages' => "[]",
        'announcement_title' => '',
        'announcement_body' => '',
        'announcement_ts' => 0,
        'destinations_json' => "[]",
        'ai_api_key' => '',
        'ai_model' => 'claude-haiku-5-5',
    ];
    $opt = get_option('bwp_umrah_app', []);
    return array_merge($defaults, is_array($opt) ? $opt : []);
}

function bwp_up_route_config() {
    $s = bwp_up_settings();
    $packages = json_decode($s['packages'], true);
    return bwp_up_json([
        'whatsapp' => $s['whatsapp'],
        'packages' => is_array($packages) ? array_values($packages) : [],
        'announcement' => [
            'title' => $s['announcement_title'],
            'body'  => $s['announcement_body'],
            'ts'    => (int) $s['announcement_ts'],
        ],
        'ai_enabled' => $s['ai_api_key'] !== '',
    ]);
}

function bwp_up_route_destinations() {
    $s = bwp_up_settings();
    $list = json_decode($s['destinations_json'], true);
    return bwp_up_json(['destinations' => is_array($list) ? array_values($list) : []]);
}

/** AI proxy — the key stays on the server; the app never sees it. */
function bwp_up_route_ai(WP_REST_Request $req) {
    if (bwp_up_rate_limited('ai', 60, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $s = bwp_up_settings();
    if ($s['ai_api_key'] === '') return bwp_up_err('AI is not configured on the website yet', 503);

    $q = trim((string) $req->get_param('question'));
    if ($q === '' || mb_strlen($q) > 2000) return bwp_up_err('Question missing or too long');
    $ctx = mb_substr((string) $req->get_param('context'), 0, 1200);

    $resp = wp_remote_post('https://api.anthropic.com/v1/messages', [
        'timeout' => 55,
        'headers' => [
            'x-api-key' => $s['ai_api_key'],
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
        ],
        'body' => wp_json_encode([
            'model' => $s['ai_model'] ?: 'claude-haiku-5-5',
            'max_tokens' => 700,
            'system' => 'You are the in-app assistant of "Umrah Trip", a Ziyarat & travel companion for Umrah pilgrims in Saudi Arabia. ' . $ctx,
            'messages' => [['role' => 'user', 'content' => $q]],
        ]),
    ]);
    if (is_wp_error($resp)) return bwp_up_err('AI upstream error: ' . $resp->get_error_message(), 502);
    $code = wp_remote_retrieve_response_code($resp);
    $body = json_decode(wp_remote_retrieve_body($resp), true);
    if ($code !== 200 || empty($body['content'][0]['text'])) {
        $msg = isset($body['error']['message']) ? $body['error']['message'] : "HTTP $code";
        return bwp_up_err('AI upstream: ' . $msg, 502);
    }
    return bwp_up_json(['answer' => $body['content'][0]['text']]);
}

// ---- Admin settings page: WP Admin → Settings → Umrah Trip App ----
add_action('admin_menu', function () {
    add_options_page('Umrah Trip App', 'Umrah Trip App', 'manage_options', 'bwp-umrah-app', 'bwp_up_admin_page');
});

function bwp_up_admin_page() {
    if (!current_user_can('manage_options')) return;
    $s = bwp_up_settings();
    if (isset($_POST['bwp_up_save']) && check_admin_referer('bwp_up_admin')) {
        $new = [
            'whatsapp' => sanitize_text_field($_POST['whatsapp'] ?? ''),
            'packages' => wp_unslash($_POST['packages'] ?? '[]'),
            'announcement_title' => sanitize_text_field($_POST['announcement_title'] ?? ''),
            'announcement_body' => sanitize_textarea_field($_POST['announcement_body'] ?? ''),
            'announcement_ts' => $s['announcement_ts'],
            'destinations_json' => wp_unslash($_POST['destinations_json'] ?? '[]'),
            'ai_api_key' => sanitize_text_field($_POST['ai_api_key'] ?? ''),
            'ai_model' => sanitize_text_field($_POST['ai_model'] ?? 'claude-haiku-5-5'),
        ];
        // Bump announcement timestamp only when its content changed.
        if ($new['announcement_title'] !== $s['announcement_title'] || $new['announcement_body'] !== $s['announcement_body']) {
            $new['announcement_ts'] = time();
        }
        foreach (['packages', 'destinations_json'] as $jf) {
            if (json_decode($new[$jf], true) === null && trim($new[$jf]) !== '[]') {
                echo '<div class="notice notice-error"><p>Invalid JSON in ' . esc_html($jf) . ' — not saved.</p></div>';
                $new[$jf] = $s[$jf];
            }
        }
        update_option('bwp_umrah_app', $new);
        $s = bwp_up_settings();
        echo '<div class="notice notice-success"><p>Saved. The app picks this up on next launch/refresh.</p></div>';
    }
    ?>
    <div class="wrap">
      <h1>Umrah Trip App — Settings</h1>
      <form method="post"><?php wp_nonce_field('bwp_up_admin'); ?>
        <table class="form-table">
          <tr><th>Sponsor WhatsApp number</th>
            <td><input type="text" name="whatsapp" value="<?php echo esc_attr($s['whatsapp']); ?>" class="regular-text" placeholder="e.g. 9665XXXXXXXX (country code, no +)">
            <p class="description">Used by the app's "Request transport" and package inquiries.</p></td></tr>
          <tr><th>Packages (JSON)</th>
            <td><textarea name="packages" rows="6" class="large-text code"><?php echo esc_textarea($s['packages']); ?></textarea>
            <p class="description">Example: <code>[{"title":"Economy Umrah 14 days","price":"PKR 285,000","details":"Visa + hotel + transport"}]</code></p></td></tr>
          <tr><th>Announcement title</th>
            <td><input type="text" name="announcement_title" value="<?php echo esc_attr($s['announcement_title']); ?>" class="regular-text"></td></tr>
          <tr><th>Announcement text</th>
            <td><textarea name="announcement_body" rows="3" class="large-text"><?php echo esc_textarea($s['announcement_body']); ?></textarea>
            <p class="description">Shown as a banner in the app; changing it notifies users on next app open.</p></td></tr>
          <tr><th>Extra destinations (JSON)</th>
            <td><textarea name="destinations_json" rows="8" class="large-text code"><?php echo esc_textarea($s['destinations_json']); ?></textarea>
            <p class="description">Array of destination objects (same fields as the app's destinations.json). They are merged into the app without an app update. Keep ids unique.</p></td></tr>
          <tr><th>AI API key (Anthropic)</th>
            <td><input type="password" name="ai_api_key" value="<?php echo esc_attr($s['ai_api_key']); ?>" class="regular-text" autocomplete="off">
            <p class="description">Powers the in-app AI assistant. Key stays on this server only.</p></td></tr>
          <tr><th>AI model</th>
            <td><input type="text" name="ai_model" value="<?php echo esc_attr($s['ai_model']); ?>" class="regular-text"></td></tr>
        </table>
        <p><button class="button button-primary" name="bwp_up_save" value="1">Save settings</button></p>
      </form>
    </div>
    <?php
}

function bwp_up_route_create(WP_REST_Request $req) {
    bwp_up_gc();
    if (bwp_up_rate_limited('create', 10, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $name = bwp_up_sanitize_name($req->get_param('name'));
    $token = wp_generate_password(32, false, false);

    for ($try = 0; $try < 5; $try++) {
        $code = bwp_up_code();
        if (bwp_up_load($code)) continue;
        $members = [$token => [
            'name' => $name, 'last_seen' => bwp_up_now(),
            'lat' => null, 'lng' => null, 'acc' => null, 'loc_at' => 0,
            'sharing' => false, 'visits' => new stdClass(),
        ]];
        if (bwp_up_save($code, $members, [], true)) {
            return bwp_up_json(['code' => $code, 'token' => $token]);
        }
    }
    return bwp_up_err('Could not create pair, try again', 500);
}

function bwp_up_route_join(WP_REST_Request $req) {
    if (bwp_up_rate_limited('join', 20, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $code = strtoupper(sanitize_text_field((string) $req->get_param('code')));
    $pair = bwp_up_load($code);
    if (!$pair) return bwp_up_err('Code not found — check the 6-character code', 404);
    if (count($pair['members']) >= 2) return bwp_up_err('This code is already paired with two devices', 409);

    $name = bwp_up_sanitize_name($req->get_param('name'));
    $token = wp_generate_password(32, false, false);
    $pair['members'][$token] = [
        'name' => $name, 'last_seen' => bwp_up_now(),
        'lat' => null, 'lng' => null, 'acc' => null, 'loc_at' => 0,
        'sharing' => false, 'visits' => new stdClass(),
    ];
    bwp_up_save($code, $pair['members'], $pair['photos']);
    return bwp_up_json(['token' => $token]);
}

function bwp_up_state_response($pair, $meToken) {
    $partner = null;
    foreach ($pair['members'] as $tkn => $m) {
        if ($tkn === $meToken) continue;
        $partner = [
            'name' => $m['name'], 'last_seen' => $m['last_seen'],
            'lat' => $m['lat'], 'lng' => $m['lng'], 'acc' => $m['acc'],
            'loc_at' => $m['loc_at'], 'sharing' => (bool) $m['sharing'],
            'visits' => $m['visits'] ?: new stdClass(),
        ];
        break;
    }
    return bwp_up_json([
        'code' => $pair['code'],
        'members' => count($pair['members']),
        'partner' => $partner,
        'photos' => array_slice($pair['photos'], -BWP_UMRAH_PAIR_MAX_PHOTOS),
    ]);
}

function bwp_up_route_sync(WP_REST_Request $req) {
    $code = strtoupper(sanitize_text_field((string) $req->get_param('code')));
    $pair = bwp_up_load($code);
    $me = bwp_up_auth($pair, (string) $req->get_param('token'));
    if (!$me) return bwp_up_err('Not authorised for this code', 403);

    $m = $pair['members'][$me];
    $m['last_seen'] = bwp_up_now();
    $m['sharing'] = (bool) $req->get_param('sharing');
    if ($m['sharing'] && is_numeric($req->get_param('lat')) && is_numeric($req->get_param('lng'))) {
        $lat = (float) $req->get_param('lat');
        $lng = (float) $req->get_param('lng');
        if ($lat >= -90 && $lat <= 90 && $lng >= -180 && $lng <= 180) {
            $m['lat'] = $lat;
            $m['lng'] = $lng;
            $m['acc'] = is_numeric($req->get_param('acc')) ? (float) $req->get_param('acc') : null;
            $m['loc_at'] = bwp_up_now();
        }
    }
    if (!$m['sharing']) { $m['lat'] = null; $m['lng'] = null; $m['acc'] = null; }

    $visits = $req->get_param('visits');
    if (is_array($visits)) {
        $clean = [];
        $i = 0;
        foreach ($visits as $destId => $ts) {
            if ($i++ > 500) break;
            $destId = sanitize_key((string) $destId);
            if ($destId !== '') $clean[$destId] = (int) $ts;
        }
        $m['visits'] = $clean ?: new stdClass();
    }

    $pair['members'][$me] = $m;
    bwp_up_save($code, $pair['members'], $pair['photos']);
    return bwp_up_state_response($pair, $me);
}

function bwp_up_route_photo(WP_REST_Request $req) {
    if (bwp_up_rate_limited('photo', 40, HOUR_IN_SECONDS)) return bwp_up_err('Too many uploads', 429);
    $code = strtoupper(sanitize_text_field((string) $req->get_param('code')));
    $pair = bwp_up_load($code);
    $me = bwp_up_auth($pair, (string) $req->get_param('token'));
    if (!$me) return bwp_up_err('Not authorised for this code', 403);

    $b64 = (string) $req->get_param('image');
    if ($b64 === '' || strlen($b64) > BWP_UMRAH_PAIR_MAX_PHOTO_B64) {
        return bwp_up_err('Image missing or too large (max ~900 KB)');
    }
    $bytes = base64_decode($b64, true);
    if ($bytes === false) return bwp_up_err('Invalid image data');

    // Only accept real JPEG/PNG payloads.
    $isJpeg = substr($bytes, 0, 3) === "\xFF\xD8\xFF";
    $isPng  = substr($bytes, 0, 8) === "\x89PNG\r\n\x1a\n";
    if (!$isJpeg && !$isPng) return bwp_up_err('Only JPEG/PNG photos are accepted');
    $ext = $isJpeg ? 'jpg' : 'png';

    $name = 'umrah-pair/' . $code . '-' . bwp_up_now() . '-' . wp_generate_password(6, false, false) . '.' . $ext;
    $up = wp_upload_bits($name, null, $bytes);
    if (!empty($up['error'])) return bwp_up_err('Upload failed: ' . $up['error'], 500);

    $caption = mb_substr(sanitize_text_field((string) $req->get_param('caption')), 0, 120);
    $pair['photos'][] = [
        'by' => $pair['members'][$me]['name'],
        'ts' => bwp_up_now(),
        'url' => $up['url'],
        'caption' => $caption !== '' ? $caption : null,
    ];
    if (count($pair['photos']) > BWP_UMRAH_PAIR_MAX_PHOTOS) {
        $pair['photos'] = array_slice($pair['photos'], -BWP_UMRAH_PAIR_MAX_PHOTOS);
    }
    bwp_up_save($code, $pair['members'], $pair['photos']);
    return bwp_up_json(['url' => $up['url']]);
}

function bwp_up_route_unpair(WP_REST_Request $req) {
    global $wpdb;
    $code = strtoupper(sanitize_text_field((string) $req->get_param('code')));
    $pair = bwp_up_load($code);
    $me = bwp_up_auth($pair, (string) $req->get_param('token'));
    if (!$me) return bwp_up_err('Not authorised for this code', 403);
    $wpdb->delete(bwp_umrah_pair_table(), ['code' => $code]);
    return bwp_up_json([]);
}
