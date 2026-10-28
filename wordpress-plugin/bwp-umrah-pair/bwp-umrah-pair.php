<?php
/**
 * Plugin Name: BWP Umrah Pair
 * Description: Umrah Trip app backend — user accounts with cloud backup/restore, friends, live chat and calls, couple pairing (code / QR / same-WiFi), live-location + visited sync, shared photos, plus the app admin panel: WhatsApp number, packages, announcements, extra destinations and the AI assistant proxy. REST namespace: umrah-pair/v1.
 * Version: 1.5.0
 * Author: BWP Experts
 * Author URI: https://bwpexperts.com
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) exit;

define('BWP_UMRAH_PAIR_VERSION', '1.5.0');
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
    $users = $wpdb->prefix . 'bwp_umrah_users';
    dbDelta("CREATE TABLE $users (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        email VARCHAR(190) NOT NULL,
        username VARCHAR(40) NULL,
        name VARCHAR(80) NOT NULL DEFAULT '',
        pass_hash VARCHAR(255) NOT NULL,
        tokens TEXT NOT NULL,
        data LONGTEXT NULL,
        data_updated BIGINT UNSIGNED NOT NULL DEFAULT 0,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY email (email),
        UNIQUE KEY username (username)
    ) $charset;");
    $friends = $wpdb->prefix . 'bwp_umrah_friends';
    dbDelta("CREATE TABLE $friends (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        a_id BIGINT UNSIGNED NOT NULL,
        b_id BIGINT UNSIGNED NOT NULL,
        status VARCHAR(12) NOT NULL DEFAULT 'pending',
        requested_by BIGINT UNSIGNED NOT NULL,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY pair (a_id, b_id),
        KEY b_id (b_id)
    ) $charset;");
    $msgs = $wpdb->prefix . 'bwp_umrah_messages';
    dbDelta("CREATE TABLE $msgs (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        thread VARCHAR(64) NOT NULL,
        sender_key VARCHAR(40) NOT NULL,
        sender_name VARCHAR(80) NOT NULL DEFAULT '',
        type VARCHAR(12) NOT NULL DEFAULT 'text',
        body TEXT NOT NULL,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (id),
        KEY thread_id (thread, id)
    ) $charset;");
    $calls = $wpdb->prefix . 'bwp_umrah_calls';
    dbDelta("CREATE TABLE $calls (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        call_id VARCHAR(24) NOT NULL,
        thread VARCHAR(64) NOT NULL,
        caller_key VARCHAR(40) NOT NULL,
        caller_name VARCHAR(80) NOT NULL DEFAULT '',
        video TINYINT(1) NOT NULL DEFAULT 0,
        status VARCHAR(12) NOT NULL DEFAULT 'ringing',
        offer LONGTEXT NULL,
        answer LONGTEXT NULL,
        created BIGINT UNSIGNED NOT NULL,
        updated BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY call_id (call_id),
        KEY thread (thread)
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

function bwp_up_client_ip() {
    foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_REAL_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'] as $h) {
        if (!empty($_SERVER[$h])) {
            $ip = trim(explode(',', (string) $_SERVER[$h])[0]);
            $ip = preg_replace('/[^0-9a-fA-F:.]/', '', $ip);
            if ($ip !== '') return $ip;
        }
    }
    return 'x';
}

function bwp_up_rate_limited($bucket, $limit, $window) {
    $ip = bwp_up_client_ip();
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

// ---- Keep our public endpoints reachable & uncached ----
// Security plugins often block the REST API for logged-out users; the app
// is always logged-out, so allow ONLY this namespace through.
add_filter('rest_authentication_errors', function ($result) {
    $uri = isset($_SERVER['REQUEST_URI']) ? (string) $_SERVER['REQUEST_URI'] : '';
    if (is_wp_error($result) && strpos($uri, 'umrah-pair/v1') !== false) return null;
    return $result;
}, 999);

add_filter('rest_post_dispatch', function ($response, $server, $request) {
    if (strpos($request->get_route(), '/umrah-pair/v1') === 0 && $response instanceof WP_REST_Response) {
        $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
        $response->header('X-LiteSpeed-Cache-Control', 'no-cache');
        $response->header('CDN-Cache-Control', 'no-store');
    }
    return $response;
}, 10, 3);

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
    register_rest_route($ns, '/account/register', $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_register']);
    register_rest_route($ns, '/account/login',    $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_login']);
    register_rest_route($ns, '/account/backup',   $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_backup']);
    register_rest_route($ns, '/account/restore',  $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_restore']);
    register_rest_route($ns, '/account/logout',   $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_logout']);
    register_rest_route($ns, '/account/delete',   $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_delete']);
    register_rest_route($ns, '/account/profile',  $pub + ['methods' => 'POST', 'callback' => 'bwp_ua_profile']);
    register_rest_route($ns, '/friends/list',     $pub + ['methods' => 'POST', 'callback' => 'bwp_uf_list']);
    register_rest_route($ns, '/friends/add',      $pub + ['methods' => 'POST', 'callback' => 'bwp_uf_add']);
    register_rest_route($ns, '/friends/respond',  $pub + ['methods' => 'POST', 'callback' => 'bwp_uf_respond']);
    register_rest_route($ns, '/friends/remove',   $pub + ['methods' => 'POST', 'callback' => 'bwp_uf_remove']);
    register_rest_route($ns, '/chat/send',        $pub + ['methods' => 'POST', 'callback' => 'bwp_uc_send']);
    register_rest_route($ns, '/chat/poll',        $pub + ['methods' => 'POST', 'callback' => 'bwp_uc_poll']);
    register_rest_route($ns, '/chat/inbox',       $pub + ['methods' => 'POST', 'callback' => 'bwp_uc_inbox']);
    register_rest_route($ns, '/call/start',  $pub + ['methods' => 'POST', 'callback' => 'bwp_ucall_start']);
    register_rest_route($ns, '/call/get',    $pub + ['methods' => 'POST', 'callback' => 'bwp_ucall_get']);
    register_rest_route($ns, '/call/answer', $pub + ['methods' => 'POST', 'callback' => 'bwp_ucall_answer']);
    register_rest_route($ns, '/call/end',    $pub + ['methods' => 'POST', 'callback' => 'bwp_ucall_end']);
});

/**
 * Same-WiFi pairing: both phones POST /nearby within 2 minutes from the same
 * public IP. First caller creates a room; the second (different token, same
 * IP) joins it automatically.
 */
function bwp_up_route_nearby(WP_REST_Request $req) {
    if (bwp_up_rate_limited('nearby', 60, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $name = bwp_up_sanitize_name($req->get_param('name'));
    $ip = bwp_up_client_ip();
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
        'call_server' => 'https://meet.jit.si',
        'stun_url' => 'stun:stun.l.google.com:19302',
        'turn_url' => '',
        'turn_username' => '',
        'turn_credential' => '',
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
        'plugin_version' => BWP_UMRAH_PAIR_VERSION,
        'call_server' => $s['call_server'] ?: 'https://meet.jit.si',
        'ice_servers' => bwp_ucall_ice_servers($s),
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
            'call_server' => esc_url_raw(trim($_POST['call_server'] ?? 'https://meet.jit.si')),
            'stun_url' => sanitize_text_field($_POST['stun_url'] ?? 'stun:stun.l.google.com:19302'),
            'turn_url' => sanitize_text_field($_POST['turn_url'] ?? ''),
            'turn_username' => sanitize_text_field($_POST['turn_username'] ?? ''),
            'turn_credential' => sanitize_text_field($_POST['turn_credential'] ?? ''),
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
          <tr><th colspan="2"><h2 style="margin:10px 0 0">In-app calls (WebRTC)</h2>
            <p class="description" style="font-weight:normal">Voice/video calls run inside the app — no login, no other app. Audio/video goes phone-to-phone; this site only connects the two phones.
            STUN is enough on most Wi-Fi. For mobile data / strict networks add a TURN server (e.g. a free metered.ca or Cloudflare TURN account) so calls always connect.</p></th></tr>
          <tr><th>STUN URL</th><td><input type="text" name="stun_url" value="<?php echo esc_attr($s['stun_url']); ?>" class="regular-text"></td></tr>
          <tr><th>TURN URL(s)</th><td><input type="text" name="turn_url" value="<?php echo esc_attr($s['turn_url']); ?>" class="regular-text" placeholder="turn:relay.example.com:3478, turns:relay.example.com:443?transport=tcp">
            <p class="description">Comma-separate several URLs.</p></td></tr>
          <tr><th>TURN username</th><td><input type="text" name="turn_username" value="<?php echo esc_attr($s['turn_username']); ?>" class="regular-text"></td></tr>
          <tr><th>TURN credential</th><td><input type="password" name="turn_credential" value="<?php echo esc_attr($s['turn_credential']); ?>" class="regular-text" autocomplete="off"></td></tr>
          <tr><th>Backup call server (Jitsi, optional)</th>
            <td><input type="url" name="call_server" value="<?php echo esc_attr($s['call_server']); ?>" class="regular-text">
            <p class="description">Voice/video calls open a private room on this Jitsi server. Default https://meet.jit.si (free). You can point this to your own Jitsi server later.</p></td></tr>
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
    if (bwp_up_rate_limited('create', 40, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
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
    if (bwp_up_rate_limited('join', 60, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $code = strtoupper(sanitize_text_field((string) $req->get_param('code')));
    $pair = bwp_up_load($code);
    if (!$pair) return bwp_up_err('Code not found — please check the 6-character code', 404);
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
    if (bwp_up_rate_limited('photo', 150, HOUR_IN_SECONDS)) return bwp_up_err('Too many uploads', 429);
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

    if (strpos(home_url(), 'https://') === 0) $up['url'] = set_url_scheme($up['url'], 'https');
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


// ================================================================ accounts
// App user accounts (separate from WordPress users). Passwords are stored
// with password_hash(); device sessions are random tokens stored as SHA-256
// hashes (max 5 devices). Each account keeps one JSON backup of the app data.

function bwp_ua_table() { global $wpdb; return $wpdb->prefix . 'bwp_umrah_users'; }

function bwp_ua_find_by_email($email) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_ua_table() . ' WHERE email = %s', $email), ARRAY_A);
}

function bwp_ua_find_by_token($token) {
    global $wpdb;
    $token = (string) $token;
    if (strlen($token) < 20) return null;
    $h = hash('sha256', $token);
    $row = $wpdb->get_row($wpdb->prepare(
        'SELECT * FROM ' . bwp_ua_table() . ' WHERE tokens LIKE %s', '%' . $wpdb->esc_like($h) . '%'
    ), ARRAY_A);
    if (!$row) return null;
    $list = json_decode($row['tokens'], true) ?: [];
    return in_array($h, $list, true) ? $row : null;
}

function bwp_ua_issue_token($row) {
    global $wpdb;
    $token = wp_generate_password(48, false, false);
    $list = json_decode($row['tokens'], true) ?: [];
    $list[] = hash('sha256', $token);
    $list = array_slice($list, -5); // keep the 5 most recent devices
    $wpdb->update(bwp_ua_table(), ['tokens' => wp_json_encode($list)], ['id' => $row['id']]);
    return $token;
}

function bwp_ua_valid_email($email) {
    return (bool) is_email($email);
}

function bwp_ua_register(WP_REST_Request $req) {
    global $wpdb;
    if (bwp_up_rate_limited('acct_reg', 15, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests, try later', 429);
    $email = strtolower(trim(sanitize_email((string) $req->get_param('email'))));
    $pass  = (string) $req->get_param('password');
    $name  = bwp_up_sanitize_name($req->get_param('name'));
    if (!bwp_ua_valid_email($email)) return bwp_up_err('Please enter a valid email address');
    if (strlen($pass) < 6) return bwp_up_err('Password must be at least 6 characters');
    if (bwp_ua_find_by_email($email)) return bwp_up_err('An account with this email already exists — please sign in', 409);
    $ok = $wpdb->insert(bwp_ua_table(), [
        'email' => $email,
        'name' => $name,
        'pass_hash' => password_hash($pass, PASSWORD_DEFAULT),
        'tokens' => '[]',
        'data' => null,
        'data_updated' => 0,
        'created' => bwp_up_now(),
    ]);
    if (!$ok) return bwp_up_err('Could not create the account, please try again', 500);
    $row = bwp_ua_find_by_email($email);
    $token = bwp_ua_issue_token($row);
    return bwp_up_json(['token' => $token, 'email' => $email, 'name' => $name, 'username' => $row['username'], 'data' => null, 'data_updated' => 0]);
}

function bwp_ua_login(WP_REST_Request $req) {
    if (bwp_up_rate_limited('acct_login', 30, HOUR_IN_SECONDS)) return bwp_up_err('Too many attempts, try later', 429);
    $email = strtolower(trim(sanitize_email((string) $req->get_param('email'))));
    $pass  = (string) $req->get_param('password');
    $row = bwp_ua_find_by_email($email);
    if (!$row || !password_verify($pass, $row['pass_hash'])) {
        return bwp_up_err('Incorrect email or password', 401);
    }
    $token = bwp_ua_issue_token($row);
    $data = $row['data'] ? json_decode($row['data'], true) : null;
    return bwp_up_json([
        'token' => $token, 'email' => $row['email'], 'name' => $row['name'], 'username' => $row['username'],
        'data' => $data, 'data_updated' => (int) $row['data_updated'],
    ]);
}

function bwp_ua_backup(WP_REST_Request $req) {
    global $wpdb;
    if (bwp_up_rate_limited('acct_backup', 400, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests', 429);
    $row = bwp_ua_find_by_token($req->get_param('token'));
    if (!$row) return bwp_up_err('Session expired — please sign in again', 401);
    $data = $req->get_param('data');
    if (!is_array($data)) return bwp_up_err('Invalid backup data');
    $json = wp_json_encode($data);
    if ($json === false || strlen($json) > 3 * 1024 * 1024) return bwp_up_err('Backup too large');
    $ts = bwp_up_now();
    $wpdb->update(bwp_ua_table(), ['data' => $json, 'data_updated' => $ts], ['id' => $row['id']]);
    return bwp_up_json(['data_updated' => $ts]);
}

function bwp_ua_restore(WP_REST_Request $req) {
    $row = bwp_ua_find_by_token($req->get_param('token'));
    if (!$row) return bwp_up_err('Session expired — please sign in again', 401);
    return bwp_up_json([
        'email' => $row['email'], 'name' => $row['name'],
        'data' => $row['data'] ? json_decode($row['data'], true) : null,
        'data_updated' => (int) $row['data_updated'],
    ]);
}

function bwp_ua_logout(WP_REST_Request $req) {
    global $wpdb;
    $token = (string) $req->get_param('token');
    $row = bwp_ua_find_by_token($token);
    if ($row) {
        $h = hash('sha256', $token);
        $list = array_values(array_filter(json_decode($row['tokens'], true) ?: [], function ($x) use ($h) { return $x !== $h; }));
        $wpdb->update(bwp_ua_table(), ['tokens' => wp_json_encode($list)], ['id' => $row['id']]);
    }
    return bwp_up_json([]);
}

function bwp_ua_delete(WP_REST_Request $req) {
    global $wpdb;
    $row = bwp_ua_find_by_token($req->get_param('token'));
    if (!$row) return bwp_up_err('Session expired — please sign in again', 401);
    if (!password_verify((string) $req->get_param('password'), $row['pass_hash'])) {
        return bwp_up_err('Incorrect password', 401);
    }
    $wpdb->delete(bwp_ua_table(), ['id' => $row['id']]);
    return bwp_up_json([]);
}

// Admin: show account count on the settings page footer.
add_action('admin_notices', function () {
    $screen = function_exists('get_current_screen') ? get_current_screen() : null;
    if (!$screen || $screen->id !== 'settings_page_bwp-umrah-app') return;
    global $wpdb;
    $n = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . bwp_ua_table());
    echo '<div class="notice notice-info"><p>Umrah Trip app accounts: <strong>' . esc_html($n) . '</strong></p></div>';
});

// ---- Admin: Settings → Umrah Trip Users (list + password reset) ----
add_action('admin_menu', function () {
    add_options_page('Umrah Trip Users', 'Umrah Trip Users', 'manage_options', 'bwp-umrah-users', 'bwp_ua_admin_page');
});

function bwp_ua_admin_page() {
    if (!current_user_can('manage_options')) return;
    global $wpdb;
    if (isset($_POST['bwp_ua_reset']) && check_admin_referer('bwp_ua_reset')) {
        $id = (int) $_POST['user_id'];
        $pw = (string) wp_unslash($_POST['new_password'] ?? '');
        if ($id > 0 && strlen($pw) >= 6) {
            // New password + sign out all devices.
            $wpdb->update(bwp_ua_table(), ['pass_hash' => password_hash($pw, PASSWORD_DEFAULT), 'tokens' => '[]'], ['id' => $id]);
            echo '<div class="notice notice-success"><p>Password reset. The user can now sign in with the new password.</p></div>';
        } else {
            echo '<div class="notice notice-error"><p>The password must be at least 6 characters.</p></div>';
        }
    }
    $rows = $wpdb->get_results('SELECT id, email, name, data_updated, created, CHAR_LENGTH(data) AS sz FROM ' . bwp_ua_table() . ' ORDER BY id DESC LIMIT 500', ARRAY_A);
    echo '<div class="wrap"><h1>Umrah Trip — App Users</h1>';
    echo '<p>Total: <strong>' . count($rows) . '</strong> (latest 500)</p>';
    echo '<table class="widefat striped"><thead><tr><th>#</th><th>Name</th><th>Email</th><th>Joined</th><th>Last backup</th><th>Backup size</th><th>Reset password</th></tr></thead><tbody>';
    foreach ($rows as $r) {
        echo '<tr><td>' . (int) $r['id'] . '</td><td>' . esc_html($r['name']) . '</td><td>' . esc_html($r['email']) . '</td>';
        echo '<td>' . esc_html(date_i18n('d M Y', (int) $r['created'])) . '</td>';
        echo '<td>' . ($r['data_updated'] ? esc_html(date_i18n('d M Y H:i', (int) $r['data_updated'])) : '—') . '</td>';
        echo '<td>' . ($r['sz'] ? esc_html(size_format((int) $r['sz'])) : '—') . '</td><td>';
        echo '<form method="post" style="display:flex;gap:6px">';
        wp_nonce_field('bwp_ua_reset');
        echo '<input type="hidden" name="user_id" value="' . (int) $r['id'] . '">';
        echo '<input type="text" name="new_password" placeholder="new password" style="width:140px">';
        echo '<button class="button" name="bwp_ua_reset" value="1">Reset</button></form></td></tr>';
    }
    echo '</tbody></table></div>';
}


// ================================================================ social: usernames, friends, chat, calls

function bwp_uf_table() { global $wpdb; return $wpdb->prefix . 'bwp_umrah_friends'; }
function bwp_uc_table() { global $wpdb; return $wpdb->prefix . 'bwp_umrah_messages'; }

function bwp_ua_public($row) {
    return ['id' => (int) $row['id'], 'name' => $row['name'], 'username' => $row['username']];
}

function bwp_ua_profile(WP_REST_Request $req) {
    global $wpdb;
    $me = bwp_ua_find_by_token($req->get_param('token'));
    if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
    $upd = [];
    $u = $req->get_param('username');
    if ($u !== null) {
        $u = strtolower(trim((string) $u, " @"));
        if (!preg_match('/^[a-z0-9_.]{3,20}$/', $u)) return bwp_up_err('Username must be 3–20 characters: letters, numbers, _ or .');
        $taken = $wpdb->get_var($wpdb->prepare('SELECT id FROM ' . bwp_ua_table() . ' WHERE username = %s AND id <> %d', $u, $me['id']));
        if ($taken) return bwp_up_err('That username is already taken', 409);
        $upd['username'] = $u;
    }
    $n = $req->get_param('name');
    if ($n !== null) $upd['name'] = bwp_up_sanitize_name($n);
    if ($upd) $wpdb->update(bwp_ua_table(), $upd, ['id' => $me['id']]);
    $me = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_ua_table() . ' WHERE id = %d', $me['id']), ARRAY_A);
    return bwp_up_json(['email' => $me['email'], 'name' => $me['name'], 'username' => $me['username']]);
}

function bwp_uf_row_for($me_id, $fid) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare(
        'SELECT * FROM ' . bwp_uf_table() . ' WHERE id = %d AND (a_id = %d OR b_id = %d)', $fid, $me_id, $me_id
    ), ARRAY_A);
}

function bwp_uf_list(WP_REST_Request $req) {
    global $wpdb;
    $me = bwp_ua_find_by_token($req->get_param('token'));
    if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
    $rows = $wpdb->get_results($wpdb->prepare(
        'SELECT * FROM ' . bwp_uf_table() . ' WHERE a_id = %d OR b_id = %d ORDER BY id DESC LIMIT 300', $me['id'], $me['id']
    ), ARRAY_A);
    $out = [];
    foreach ($rows as $f) {
        $other_id = ((int) $f['a_id'] === (int) $me['id']) ? (int) $f['b_id'] : (int) $f['a_id'];
        $o = $wpdb->get_row($wpdb->prepare('SELECT id, name, username FROM ' . bwp_ua_table() . ' WHERE id = %d', $other_id), ARRAY_A);
        if (!$o) continue;
        $out[] = [
            'fid' => (int) $f['id'],
            'status' => $f['status'],
            'incoming' => $f['status'] === 'pending' && (int) $f['requested_by'] !== (int) $me['id'],
            'user' => bwp_ua_public($o),
            'thread' => 'dm:' . (int) $f['id'],
        ];
    }
    return bwp_up_json(['me' => bwp_ua_public($me), 'friends' => $out]);
}

function bwp_uf_add(WP_REST_Request $req) {
    global $wpdb;
    if (bwp_up_rate_limited('friend_add', 60, HOUR_IN_SECONDS)) return bwp_up_err('Too many requests, please try later', 429);
    $me = bwp_ua_find_by_token($req->get_param('token'));
    if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
    $q = strtolower(trim((string) $req->get_param('query'), " @"));
    if ($q === '') return bwp_up_err('Enter an email address or username');
    $col = is_email($q) ? 'email' : 'username';
    $o = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_ua_table() . " WHERE $col = %s", $q), ARRAY_A);
    if (!$o) return bwp_up_err('No Umrah Trip account found with that ' . ($col === 'email' ? 'email address' : 'username'), 404);
    if ((int) $o['id'] === (int) $me['id']) return bwp_up_err('You cannot add yourself');
    $a = min((int) $me['id'], (int) $o['id']); $b = max((int) $me['id'], (int) $o['id']);
    $f = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_uf_table() . ' WHERE a_id = %d AND b_id = %d', $a, $b), ARRAY_A);
    if ($f) {
        if ($f['status'] === 'accepted') return bwp_up_json(['status' => 'accepted', 'message' => 'You are already friends']);
        if ((int) $f['requested_by'] !== (int) $me['id']) { // they asked me earlier → accept
            $wpdb->update(bwp_uf_table(), ['status' => 'accepted'], ['id' => $f['id']]);
            return bwp_up_json(['status' => 'accepted', 'message' => 'Friend request accepted']);
        }
        return bwp_up_json(['status' => 'pending', 'message' => 'Request already sent']);
    }
    $wpdb->insert(bwp_uf_table(), ['a_id' => $a, 'b_id' => $b, 'status' => 'pending', 'requested_by' => $me['id'], 'created' => bwp_up_now()]);
    return bwp_up_json(['status' => 'pending', 'message' => 'Friend request sent to ' . $o['name']]);
}

function bwp_uf_respond(WP_REST_Request $req) {
    global $wpdb;
    $me = bwp_ua_find_by_token($req->get_param('token'));
    if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
    $f = bwp_uf_row_for($me['id'], (int) $req->get_param('fid'));
    if (!$f || $f['status'] !== 'pending' || (int) $f['requested_by'] === (int) $me['id']) return bwp_up_err('Request not found', 404);
    if ($req->get_param('accept')) {
        $wpdb->update(bwp_uf_table(), ['status' => 'accepted'], ['id' => $f['id']]);
    } else {
        $wpdb->delete(bwp_uf_table(), ['id' => $f['id']]);
    }
    return bwp_up_json([]);
}

function bwp_uf_remove(WP_REST_Request $req) {
    global $wpdb;
    $me = bwp_ua_find_by_token($req->get_param('token'));
    if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
    $f = bwp_uf_row_for($me['id'], (int) $req->get_param('fid'));
    if (!$f) return bwp_up_err('Not found', 404);
    $wpdb->delete(bwp_uf_table(), ['id' => $f['id']]);
    $wpdb->delete(bwp_uc_table(), ['thread' => 'dm:' . (int) $f['id']]);
    return bwp_up_json([]);
}

/**
 * Resolve who is talking in a thread. Returns [sender_key, sender_name] or WP_REST_Response error.
 *  - dm:<fid>   → account token, friendship must be accepted
 *  - pair:<code> → pairing code + pairing token
 */
function bwp_uc_auth(WP_REST_Request $req, $thread) {
    if (strpos($thread, 'dm:') === 0) {
        $me = bwp_ua_find_by_token($req->get_param('token'));
        if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
        $f = bwp_uf_row_for($me['id'], (int) substr($thread, 3));
        if (!$f || $f['status'] !== 'accepted') return bwp_up_err('Not allowed in this chat', 403);
        return ['u:' . (int) $me['id'], $me['name']];
    }
    if (strpos($thread, 'pair:') === 0) {
        $code = strtoupper(substr($thread, 5));
        $pair = bwp_up_load($code);
        $tkn = bwp_up_auth($pair, (string) $req->get_param('ptoken'));
        if (!$tkn) return bwp_up_err('Not authorised for this pairing', 403);
        return ['p:' . substr(hash('sha256', $tkn), 0, 16), $pair['members'][$tkn]['name']];
    }
    return bwp_up_err('Unknown chat', 400);
}

function bwp_uc_format($m, $my_key) {
    $body = $m['body'];
    $dec = in_array($m['type'], ['location', 'call'], true) ? json_decode($body, true) : null;
    return [
        'id' => (int) $m['id'], 'type' => $m['type'],
        'body' => $dec !== null ? $dec : $body,
        'name' => $m['sender_name'], 'mine' => $m['sender_key'] === $my_key,
        'ts' => (int) $m['created'],
    ];
}

function bwp_uc_send(WP_REST_Request $req) {
    global $wpdb;
    if (bwp_up_rate_limited('chat_send', 600, HOUR_IN_SECONDS)) return bwp_up_err('Too many messages, slow down', 429);
    $thread = substr(preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $req->get_param('thread')), 0, 60);
    $who = bwp_uc_auth($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $type = (string) $req->get_param('type');
    if (!in_array($type, ['text', 'image', 'location', 'call'], true)) $type = 'text';

    if ($type === 'image') {
        $b64 = (string) $req->get_param('image');
        if ($b64 === '' || strlen($b64) > BWP_UMRAH_PAIR_MAX_PHOTO_B64) return bwp_up_err('Image missing or too large (max ~900 KB)');
        $bytes = base64_decode($b64, true);
        if ($bytes === false) return bwp_up_err('Invalid image data');
        $isJpeg = substr($bytes, 0, 3) === "\xFF\xD8\xFF";
        $isPng = substr($bytes, 0, 8) === "\x89PNG\r\n\x1a\n";
        if (!$isJpeg && !$isPng) return bwp_up_err('Only JPEG/PNG photos are accepted');
        $up = wp_upload_bits('umrah-chat/' . md5($thread) . '-' . bwp_up_now() . '-' . wp_generate_password(6, false, false) . ($isJpeg ? '.jpg' : '.png'), null, $bytes);
        if (!empty($up['error'])) return bwp_up_err('Upload failed: ' . $up['error'], 500);
        $body = strpos(home_url(), 'https://') === 0 ? set_url_scheme($up['url'], 'https') : $up['url'];
    } elseif ($type === 'location' || $type === 'call') {
        $b = $req->get_param('body');
        if (!is_array($b)) return bwp_up_err('Invalid message');
        if ($type === 'location') {
            $b = ['lat' => (float) ($b['lat'] ?? 0), 'lng' => (float) ($b['lng'] ?? 0)];
        } else {
            $url = esc_url_raw((string) ($b['url'] ?? ''));
            if ($url === '') return bwp_up_err('Invalid call link');
            $b = ['url' => $url, 'video' => !empty($b['video'])];
        }
        $body = wp_json_encode($b);
    } else {
        $body = trim(wp_strip_all_tags((string) $req->get_param('body')));
        if ($body === '') return bwp_up_err('Empty message');
        $body = mb_substr($body, 0, 2000);
    }
    $wpdb->insert(bwp_uc_table(), [
        'thread' => $thread, 'sender_key' => $who[0], 'sender_name' => $who[1],
        'type' => $type, 'body' => $body, 'created' => bwp_up_now(),
    ]);
    $m = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_uc_table() . ' WHERE id = %d', $wpdb->insert_id), ARRAY_A);
    return bwp_up_json(['message' => bwp_uc_format($m, $who[0])]);
}

function bwp_uc_poll(WP_REST_Request $req) {
    global $wpdb;
    $thread = substr(preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $req->get_param('thread')), 0, 60);
    $who = bwp_uc_auth($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $after = (int) $req->get_param('after');
    if ($after > 0) {
        $rows = $wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . bwp_uc_table() . ' WHERE thread = %s AND id > %d ORDER BY id ASC LIMIT 200', $thread, $after
        ), ARRAY_A);
    } else { // first load: latest 100
        $rows = array_reverse($wpdb->get_results($wpdb->prepare(
            'SELECT * FROM ' . bwp_uc_table() . ' WHERE thread = %s ORDER BY id DESC LIMIT 100', $thread
        ), ARRAY_A));
    }
    $out = array_map(function ($m) use ($who) { return bwp_uc_format($m, $who[0]); }, $rows);
    return bwp_up_json(['messages' => $out]);
}

/** Latest message per friend thread (for unread badges + incoming call alerts). */
function bwp_uc_inbox(WP_REST_Request $req) {
    global $wpdb;
    $out = [];
    $pending = 0;
    $tok = (string) $req->get_param('token');
    if ($tok !== '') {
        $me = bwp_ua_find_by_token($tok);
        if (!$me) return bwp_up_err('Session expired — please sign in again', 401);
        $fids = $wpdb->get_col($wpdb->prepare(
            "SELECT id FROM " . bwp_uf_table() . " WHERE (a_id = %d OR b_id = %d) AND status = 'accepted'", $me['id'], $me['id']
        ));
        $mk = 'u:' . (int) $me['id'];
        foreach ($fids as $f) {
            $th = 'dm:' . (int) $f;
            $m = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_uc_table() . ' WHERE thread = %s ORDER BY id DESC LIMIT 1', $th), ARRAY_A);
            if ($m) $out[$th] = bwp_uc_format($m, $mk);
        }
        $pending = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM " . bwp_uf_table() . " WHERE (a_id = %d OR b_id = %d) AND status = 'pending' AND requested_by <> %d",
            $me['id'], $me['id'], $me['id']
        ));
    }
    $pt = substr(preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $req->get_param('pair_thread')), 0, 60);
    if (strpos($pt, 'pair:') === 0) {
        $who = bwp_uc_auth($req, $pt);
        if (!($who instanceof WP_REST_Response)) {
            $m = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . bwp_uc_table() . ' WHERE thread = %s ORDER BY id DESC LIMIT 1', $pt), ARRAY_A);
            if ($m) $out[$pt] = bwp_uc_format($m, $who[0]);
        }
    }
    return bwp_up_json(['latest' => (object) $out, 'pending_requests' => $pending]);
}

// Light clean-up: chat messages older than 120 days.
add_action('init', function () {
    if (get_transient('bwp_uc_gc')) return;
    set_transient('bwp_uc_gc', 1, DAY_IN_SECONDS);
    global $wpdb;
    $wpdb->query($wpdb->prepare('DELETE FROM ' . bwp_uc_table() . ' WHERE created < %d', time() - 120 * DAY_IN_SECONDS));
});


// ================================================================ in-app calls (WebRTC signaling)
// Non-trickle ICE: each side sends ONE complete SDP (with candidates) — the
// site only relays offer/answer; media flows peer-to-peer (or via TURN).

function bwp_ucall_table() { global $wpdb; return $wpdb->prefix . 'bwp_umrah_calls'; }

function bwp_ucall_ice_servers($s) {
    $list = [];
    $stun = trim((string) ($s['stun_url'] ?? ''));
    if ($stun !== '') $list[] = ['urls' => array_values(array_filter(array_map('trim', explode(',', $stun))))];
    $turn = trim((string) ($s['turn_url'] ?? ''));
    if ($turn !== '') {
        $list[] = [
            'urls' => array_values(array_filter(array_map('trim', explode(',', $turn)))),
            'username' => (string) ($s['turn_username'] ?? ''),
            'credential' => (string) ($s['turn_credential'] ?? ''),
        ];
    }
    return $list;
}

function bwp_ucall_load($thread, $call_id) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare(
        'SELECT * FROM ' . bwp_ucall_table() . ' WHERE call_id = %s AND thread = %s', $call_id, $thread
    ), ARRAY_A);
}

function bwp_ucall_thread(WP_REST_Request $req) {
    return substr(preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $req->get_param('thread')), 0, 60);
}

function bwp_ucall_state($c, $my_key) {
    $status = $c['status'];
    if ($status === 'ringing' && bwp_up_now() - (int) $c['created'] > 60) $status = 'missed';
    return [
        'call_id' => $c['call_id'], 'status' => $status, 'video' => (bool) $c['video'],
        'caller_name' => $c['caller_name'], 'i_am_caller' => $c['caller_key'] === $my_key,
        'offer' => $c['offer'] ? json_decode($c['offer'], true) : null,
        'answer' => $c['answer'] ? json_decode($c['answer'], true) : null,
        'created' => (int) $c['created'],
    ];
}

function bwp_ucall_start(WP_REST_Request $req) {
    global $wpdb;
    if (bwp_up_rate_limited('call_start', 120, HOUR_IN_SECONDS)) return bwp_up_err('Too many calls, please wait', 429);
    $thread = bwp_ucall_thread($req);
    $who = bwp_uc_auth($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $offer = $req->get_param('offer');
    if (!is_array($offer) || empty($offer['sdp'])) return bwp_up_err('Missing call offer');
    $video = (bool) $req->get_param('video');
    $call_id = strtolower(wp_generate_password(16, false, false));
    $now = bwp_up_now();
    $wpdb->insert(bwp_ucall_table(), [
        'call_id' => $call_id, 'thread' => $thread, 'caller_key' => $who[0], 'caller_name' => $who[1],
        'video' => $video ? 1 : 0, 'status' => 'ringing',
        'offer' => wp_json_encode(['type' => (string) ($offer['type'] ?? 'offer'), 'sdp' => (string) $offer['sdp']]),
        'answer' => null, 'created' => $now, 'updated' => $now,
    ]);
    // Drop a call card into the chat so the other side sees it.
    $wpdb->insert(bwp_uc_table(), [
        'thread' => $thread, 'sender_key' => $who[0], 'sender_name' => $who[1], 'type' => 'call',
        'body' => wp_json_encode(['call_id' => $call_id, 'video' => $video]), 'created' => $now,
    ]);
    return bwp_up_json(['call_id' => $call_id]);
}

function bwp_ucall_get(WP_REST_Request $req) {
    $thread = bwp_ucall_thread($req);
    $who = bwp_uc_auth($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $c = bwp_ucall_load($thread, (string) $req->get_param('call_id'));
    if (!$c) return bwp_up_err('Call not found', 404);
    return bwp_up_json(['call' => bwp_ucall_state($c, $who[0])]);
}

function bwp_ucall_answer(WP_REST_Request $req) {
    global $wpdb;
    $thread = bwp_ucall_thread($req);
    $who = bwp_uc_auth($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $c = bwp_ucall_load($thread, (string) $req->get_param('call_id'));
    if (!$c) return bwp_up_err('Call not found', 404);
    if ($c['caller_key'] === $who[0]) return bwp_up_err('You started this call');
    if ($c['status'] !== 'ringing') return bwp_up_err('This call has already ended', 409);
    $ans = $req->get_param('answer');
    if (!is_array($ans) || empty($ans['sdp'])) return bwp_up_err('Missing answer');
    $wpdb->update(bwp_ucall_table(), [
        'answer' => wp_json_encode(['type' => (string) ($ans['type'] ?? 'answer'), 'sdp' => (string) $ans['sdp']]),
        'status' => 'active', 'updated' => bwp_up_now(),
    ], ['id' => $c['id']]);
    return bwp_up_json([]);
}

function bwp_ucall_end(WP_REST_Request $req) {
    global $wpdb;
    $thread = bwp_ucall_thread($req);
    $who = bwp_uc_auth($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $c = bwp_ucall_load($thread, (string) $req->get_param('call_id'));
    if (!$c) return bwp_up_err('Call not found', 404);
    $st = $req->get_param('status') === 'declined' ? 'declined' : 'ended';
    $wpdb->update(bwp_ucall_table(), ['status' => $st, 'updated' => bwp_up_now()], ['id' => $c['id']]);
    return bwp_up_json([]);
}

// Clean up call rows older than 2 days.
add_action('init', function () {
    if (get_transient('bwp_ucall_gc')) return;
    set_transient('bwp_ucall_gc', 1, 6 * HOUR_IN_SECONDS);
    global $wpdb;
    $wpdb->query($wpdb->prepare('DELETE FROM ' . bwp_ucall_table() . ' WHERE created < %d', time() - 2 * DAY_IN_SECONDS));
});
