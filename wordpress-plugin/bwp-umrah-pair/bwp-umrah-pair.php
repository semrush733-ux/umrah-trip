<?php
/**
 * Plugin Name: BWP Umrah Pair
 * Description: Backend for the Umrah Trip app couple-pairing feature — one security code links two devices for consensual live-location sharing, shared visited-places sync and a shared photo gallery. REST namespace: umrah-pair/v1.
 * Version: 1.0.0
 * Author: BWP Experts
 * Author URI: https://bwpexperts.com
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) exit;

define('BWP_UMRAH_PAIR_VERSION', '1.0.0');
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
    register_rest_route($ns, '/sync',   $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_sync']);
    register_rest_route($ns, '/photo',  $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_photo']);
    register_rest_route($ns, '/unpair', $pub + ['methods' => 'POST', 'callback' => 'bwp_up_route_unpair']);
});

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
