<?php
/**
 * Plugin Name: BWP Volo Chat
 * Description: Backend for the Volo Chat app — phone number sign-up with SMS code (Twilio Verify), email verification, profiles, contacts, live chat with delivered/seen ticks, voice notes, photos, voice/video calls (WebRTC signaling) with call history, groups, Status (24-hour stories), live location, meeting points, SOS alerts and optional push notifications. REST namespace: volo/v1.
 * Version: 1.0.0
 * Author: BWP Experts
 * Author URI: https://bwpexperts.com
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) exit;

define('VOLO_VERSION', '1.0.0');
define('VOLO_MAX_IMAGE_B64', 1400000);   // ~1 MB binary
define('VOLO_MAX_AUDIO_B64', 2600000);   // ~2 MB binary
define('VOLO_STATUS_TTL', DAY_IN_SECONDS);

register_activation_hook(__FILE__, 'volo_install');
add_action('plugins_loaded', function () {
    if (get_option('volo_db_version') !== VOLO_VERSION) volo_install();
});

function volo_t($name) { global $wpdb; return $wpdb->prefix . 'volo_' . $name; }

function volo_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $c = $wpdb->get_charset_collate();
    dbDelta("CREATE TABLE " . volo_t('users') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        phone VARCHAR(20) NOT NULL,
        email VARCHAR(190) NULL,
        email_verified TINYINT(1) NOT NULL DEFAULT 0,
        name VARCHAR(80) NOT NULL DEFAULT '',
        about VARCHAR(140) NOT NULL DEFAULT 'Hey there! I am using Volo Chat.',
        username VARCHAR(40) NULL,
        avatar VARCHAR(255) NULL,
        tokens TEXT NOT NULL,
        blocked TINYINT(1) NOT NULL DEFAULT 0,
        loc_lat DOUBLE NULL,
        loc_lng DOUBLE NULL,
        loc_acc FLOAT NULL,
        loc_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
        loc_share TINYINT(1) NOT NULL DEFAULT 0,
        last_seen BIGINT UNSIGNED NOT NULL DEFAULT 0,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY phone (phone),
        UNIQUE KEY username (username),
        KEY email (email)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('contacts') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        a_id BIGINT UNSIGNED NOT NULL,
        b_id BIGINT UNSIGNED NOT NULL,
        status VARCHAR(12) NOT NULL DEFAULT 'accepted',
        added_by BIGINT UNSIGNED NOT NULL,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY pair (a_id, b_id),
        KEY b_id (b_id)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('messages') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        thread VARCHAR(64) NOT NULL,
        sender_key VARCHAR(40) NOT NULL,
        sender_name VARCHAR(80) NOT NULL DEFAULT '',
        type VARCHAR(12) NOT NULL DEFAULT 'text',
        body TEXT NOT NULL,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id),
        KEY thread_id (thread, id)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('reads') . " (
        thread VARCHAR(64) NOT NULL,
        member_key VARCHAR(40) NOT NULL,
        delivered BIGINT UNSIGNED NOT NULL DEFAULT 0,
        seen BIGINT UNSIGNED NOT NULL DEFAULT 0,
        typing_until BIGINT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY  (thread, member_key)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('calls') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        call_id VARCHAR(24) NOT NULL,
        thread VARCHAR(64) NOT NULL,
        caller_key VARCHAR(40) NOT NULL,
        caller_name VARCHAR(80) NOT NULL DEFAULT '',
        video TINYINT(1) NOT NULL DEFAULT 0,
        status VARCHAR(12) NOT NULL DEFAULT 'ringing',
        offer LONGTEXT NULL,
        answer LONGTEXT NULL,
        answered BIGINT UNSIGNED NOT NULL DEFAULT 0,
        ended BIGINT UNSIGNED NOT NULL DEFAULT 0,
        created BIGINT UNSIGNED NOT NULL,
        updated BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY call_id (call_id),
        KEY thread (thread)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('groups') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        name VARCHAR(60) NOT NULL,
        owner_id BIGINT UNSIGNED NOT NULL,
        avatar VARCHAR(255) NULL,
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('group_members') . " (
        group_id BIGINT UNSIGNED NOT NULL,
        user_id BIGINT UNSIGNED NOT NULL,
        joined BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (group_id, user_id),
        KEY user_id (user_id)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('statuses') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        user_id BIGINT UNSIGNED NOT NULL,
        type VARCHAR(10) NOT NULL DEFAULT 'text',
        body TEXT NOT NULL,
        bg VARCHAR(9) NOT NULL DEFAULT '',
        caption VARCHAR(300) NOT NULL DEFAULT '',
        created BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id),
        KEY user_created (user_id, created)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('status_views') . " (
        status_id BIGINT UNSIGNED NOT NULL,
        viewer_id BIGINT UNSIGNED NOT NULL,
        viewed BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (status_id, viewer_id)
    ) $c;");
    dbDelta("CREATE TABLE " . volo_t('push') . " (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        member_key VARCHAR(40) NOT NULL,
        fcm VARCHAR(255) NOT NULL,
        platform VARCHAR(10) NOT NULL DEFAULT '',
        updated BIGINT UNSIGNED NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY fcm (fcm),
        KEY member_key (member_key)
    ) $c;");
    update_option('volo_db_version', VOLO_VERSION);
}

// ================================================================ helpers

function volo_now() { return time(); }
function volo_json($data, $code = 200) { return new WP_REST_Response(array_merge(['ok' => $code === 200], $data), $code); }
function volo_err($msg, $code = 400) { return new WP_REST_Response(['ok' => false, 'error' => $msg], $code); }

function volo_ip() {
    foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_REAL_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'] as $h) {
        if (!empty($_SERVER[$h])) {
            $ip = preg_replace('/[^0-9a-fA-F:.]/', '', trim(explode(',', (string) $_SERVER[$h])[0]));
            if ($ip !== '') return $ip;
        }
    }
    return 'x';
}

function volo_limited($bucket, $limit, $window, $extra = '') {
    $key = 'volo_rl_' . md5($bucket . '|' . volo_ip() . '|' . $extra);
    $n = (int) get_transient($key);
    if ($n >= $limit) return true;
    set_transient($key, $n + 1, $window);
    return false;
}

function volo_settings() {
    $d = [
        'twilio_sid' => '', 'twilio_token' => '', 'twilio_verify_sid' => '',
        'test_code' => '', // when set, this code works for every number (testing only)
        'require_email' => 1,
        'stun_url' => 'stun:stun.l.google.com:19302',
        'turn_url' => '', 'turn_username' => '', 'turn_credential' => '',
        'fcm_api_key' => '', 'fcm_project_id' => '', 'fcm_sender_id' => '',
        'fcm_android_app_id' => '', 'fcm_ios_app_id' => '', 'fcm_service_json' => '',
        'mail_from_name' => 'Volo Chat',
    ];
    $o = get_option('volo_settings', []);
    return array_merge($d, is_array($o) ? $o : []);
}

/** Normalise a phone number to E.164 (+923001234567). */
function volo_phone($raw) {
    $p = preg_replace('/[^0-9+]/', '', (string) $raw);
    if (strpos($p, '00') === 0) $p = '+' . substr($p, 2);
    if ($p === '' || $p[0] !== '+') return null;
    $digits = substr($p, 1);
    if (!ctype_digit($digits) || strlen($digits) < 8 || strlen($digits) > 15) return null;
    return '+' . $digits;
}

function volo_user_by_token($token) {
    global $wpdb;
    $token = (string) $token;
    if (strlen($token) < 20) return null;
    $h = hash('sha256', $token);
    $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('users') . ' WHERE tokens LIKE %s', '%' . $wpdb->esc_like($h) . '%'), ARRAY_A);
    if (!$row || !in_array($h, json_decode($row['tokens'], true) ?: [], true) || $row['blocked']) return null;
    if (volo_now() - (int) $row['last_seen'] > 30) {
        $wpdb->update(volo_t('users'), ['last_seen' => volo_now()], ['id' => $row['id']]);
    }
    return $row;
}

function volo_me(WP_REST_Request $req) {
    $me = volo_user_by_token($req->get_param('token'));
    return $me ?: volo_err('Session expired — please sign in again', 401);
}

function volo_issue_token($row) {
    global $wpdb;
    $token = wp_generate_password(48, false, false);
    $list = json_decode($row['tokens'], true) ?: [];
    $list[] = hash('sha256', $token);
    $list = array_slice($list, -5);
    $wpdb->update(volo_t('users'), ['tokens' => wp_json_encode($list)], ['id' => $row['id']]);
    return $token;
}

function volo_user($id) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('users') . ' WHERE id = %d', $id), ARRAY_A);
}

/** Public profile as other people see it. */
function volo_public($u) {
    $online = volo_now() - (int) $u['last_seen'] < 45;
    return [
        'id' => (int) $u['id'], 'name' => $u['name'], 'phone' => $u['phone'], 'about' => $u['about'],
        'username' => $u['username'], 'avatar' => $u['avatar'] ?: null,
        'online' => $online, 'last_seen' => (int) $u['last_seen'],
    ];
}

/** My own profile. */
function volo_self($u) {
    return volo_public($u) + ['email' => $u['email'], 'email_verified' => (bool) $u['email_verified']];
}

function volo_https($url) { return strpos(home_url(), 'https://') === 0 ? set_url_scheme($url, 'https') : $url; }

function volo_store_image($b64, $prefix) {
    if ($b64 === '' || strlen($b64) > VOLO_MAX_IMAGE_B64) return volo_err('Image missing or too large (max ~1 MB)');
    $bytes = base64_decode($b64, true);
    if ($bytes === false) return volo_err('Invalid image data');
    $jpg = substr($bytes, 0, 3) === "\xFF\xD8\xFF";
    $png = substr($bytes, 0, 8) === "\x89PNG\r\n\x1a\n";
    if (!$jpg && !$png) return volo_err('Only JPEG/PNG photos are accepted');
    $up = wp_upload_bits($prefix . '-' . volo_now() . '-' . wp_generate_password(8, false, false) . ($jpg ? '.jpg' : '.png'), null, $bytes);
    if (!empty($up['error'])) return volo_err('Upload failed: ' . $up['error'], 500);
    return volo_https($up['url']);
}

function volo_store_audio($b64, $prefix) {
    if ($b64 === '' || strlen($b64) > VOLO_MAX_AUDIO_B64) return volo_err('Voice message missing or too long');
    $bytes = base64_decode($b64, true);
    if ($bytes === false || strlen($bytes) < 64) return volo_err('Invalid audio data');
    $mp4 = substr($bytes, 4, 4) === 'ftyp';
    $adts = (ord($bytes[0]) === 0xFF) && ((ord($bytes[1]) & 0xF6) === 0xF0);
    if (!$mp4 && !$adts) return volo_err('Only AAC / M4A voice messages are accepted');
    $up = wp_upload_bits($prefix . '-' . volo_now() . '-' . wp_generate_password(8, false, false) . ($mp4 ? '.m4a' : '.aac'), null, $bytes);
    if (!empty($up['error'])) return volo_err('Upload failed: ' . $up['error'], 500);
    return volo_https($up['url']);
}

function volo_thread_param(WP_REST_Request $req, $name = 'thread') {
    return substr(preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $req->get_param($name)), 0, 60);
}

// Keep our endpoints reachable & uncached even with security/caching plugins.
add_filter('rest_authentication_errors', function ($result) {
    $uri = isset($_SERVER['REQUEST_URI']) ? (string) $_SERVER['REQUEST_URI'] : '';
    if (is_wp_error($result) && strpos($uri, 'volo/v1') !== false) return null;
    return $result;
}, 999);

add_filter('rest_post_dispatch', function ($response, $server, $request) {
    if (strpos($request->get_route(), '/volo/v1') === 0 && $response instanceof WP_REST_Response) {
        $response->header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0');
        $response->header('X-LiteSpeed-Cache-Control', 'no-cache');
        $response->header('CDN-Cache-Control', 'no-store');
    }
    return $response;
}, 10, 3);

// ================================================================ routes

add_action('rest_api_init', function () {
    $ns = 'volo/v1';
    $routes = [
        ['GET', '/config', 'volo_r_config'],
        ['POST', '/auth/start', 'volo_r_auth_start'],
        ['POST', '/auth/verify', 'volo_r_auth_verify'],
        ['POST', '/auth/logout', 'volo_r_auth_logout'],
        ['POST', '/me', 'volo_r_me'],
        ['POST', '/profile', 'volo_r_profile'],
        ['POST', '/email/send', 'volo_r_email_send'],
        ['POST', '/email/verify', 'volo_r_email_verify'],
        ['POST', '/account/delete', 'volo_r_account_delete'],
        ['POST', '/contacts/list', 'volo_r_contacts_list'],
        ['POST', '/contacts/add', 'volo_r_contacts_add'],
        ['POST', '/contacts/remove', 'volo_r_contacts_remove'],
        ['POST', '/contacts/match', 'volo_r_contacts_match'],
        ['POST', '/chat/send', 'volo_r_chat_send'],
        ['POST', '/chat/poll', 'volo_r_chat_poll'],
        ['POST', '/chat/inbox', 'volo_r_chat_inbox'],
        ['POST', '/chat/typing', 'volo_r_chat_typing'],
        ['POST', '/chat/delete', 'volo_r_chat_delete'],
        ['POST', '/call/start', 'volo_r_call_start'],
        ['POST', '/call/get', 'volo_r_call_get'],
        ['POST', '/call/answer', 'volo_r_call_answer'],
        ['POST', '/call/end', 'volo_r_call_end'],
        ['POST', '/call/history', 'volo_r_call_history'],
        ['POST', '/groups/create', 'volo_r_groups_create'],
        ['POST', '/groups/list', 'volo_r_groups_list'],
        ['POST', '/groups/add', 'volo_r_groups_add'],
        ['POST', '/groups/leave', 'volo_r_groups_leave'],
        ['POST', '/groups/locations', 'volo_r_groups_locations'],
        ['POST', '/loc/update', 'volo_r_loc_update'],
        ['POST', '/meet/set', 'volo_r_meet_set'],
        ['POST', '/meet/get', 'volo_r_meet_get'],
        ['POST', '/sos/send', 'volo_r_sos_send'],
        ['POST', '/status/post', 'volo_r_status_post'],
        ['POST', '/status/feed', 'volo_r_status_feed'],
        ['POST', '/status/view', 'volo_r_status_view'],
        ['POST', '/status/viewers', 'volo_r_status_viewers'],
        ['POST', '/status/delete', 'volo_r_status_delete'],
        ['POST', '/push/register', 'volo_r_push_register'],
    ];
    foreach ($routes as [$m, $path, $cb]) {
        register_rest_route($ns, $path, ['methods' => $m, 'callback' => $cb, 'permission_callback' => '__return_true']);
    }
});

function volo_r_config() {
    $s = volo_settings();
    return volo_json([
        'version' => VOLO_VERSION,
        'sms_ready' => volo_sms_ready(),
        'require_email' => (bool) $s['require_email'],
        'ice_servers' => volo_ice_servers($s),
        'firebase' => ($s['fcm_api_key'] !== '' && $s['fcm_project_id'] !== '' && $s['fcm_sender_id'] !== '') ? [
            'api_key' => $s['fcm_api_key'], 'project_id' => $s['fcm_project_id'], 'sender_id' => $s['fcm_sender_id'],
            'android_app_id' => $s['fcm_android_app_id'], 'ios_app_id' => $s['fcm_ios_app_id'],
        ] : null,
    ]);
}

function volo_ice_servers($s) {
    $list = [];
    $stun = trim((string) $s['stun_url']);
    if ($stun !== '') $list[] = ['urls' => array_values(array_filter(array_map('trim', explode(',', $stun))))];
    $turn = trim((string) $s['turn_url']);
    if ($turn !== '') $list[] = [
        'urls' => array_values(array_filter(array_map('trim', explode(',', $turn)))),
        'username' => (string) $s['turn_username'], 'credential' => (string) $s['turn_credential'],
    ];
    return $list;
}

// ================================================================ phone sign-in (Twilio Verify)

function volo_sms_ready() {
    $s = volo_settings();
    return $s['twilio_sid'] !== '' && $s['twilio_token'] !== '' && $s['twilio_verify_sid'] !== '';
}

function volo_twilio($path, $body) {
    $s = volo_settings();
    $r = wp_remote_post('https://verify.twilio.com/v2/Services/' . rawurlencode($s['twilio_verify_sid']) . $path, [
        'timeout' => 15,
        'headers' => ['Authorization' => 'Basic ' . base64_encode($s['twilio_sid'] . ':' . $s['twilio_token'])],
        'body' => $body,
    ]);
    if (is_wp_error($r)) return [0, ['message' => $r->get_error_message()]];
    return [(int) wp_remote_retrieve_response_code($r), json_decode(wp_remote_retrieve_body($r), true) ?: []];
}

function volo_r_auth_start(WP_REST_Request $req) {
    $phone = volo_phone($req->get_param('phone'));
    if (!$phone) return volo_err('Enter your number with country code, e.g. +92 300 1234567');
    if (volo_limited('otp_ip', 12, HOUR_IN_SECONDS) || volo_limited('otp_phone', 5, HOUR_IN_SECONDS, $phone)) {
        return volo_err('Too many codes requested. Please wait a while and try again.', 429);
    }
    $s = volo_settings();
    if (volo_sms_ready()) {
        [$code, $j] = volo_twilio('/Verifications', ['To' => $phone, 'Channel' => 'sms']);
        if ($code >= 200 && $code < 300) return volo_json(['sent' => true, 'phone' => $phone]);
        return volo_err('Could not send the SMS: ' . ($j['message'] ?? 'Twilio error ' . $code), 502);
    }
    if ($s['test_code'] !== '') {
        return volo_json(['sent' => true, 'phone' => $phone, 'test_mode' => true]);
    }
    return volo_err('SMS sign-in is not set up yet. (Admin: WP Admin → Settings → Volo Chat → Twilio.)', 503);
}

function volo_r_auth_verify(WP_REST_Request $req) {
    global $wpdb;
    $phone = volo_phone($req->get_param('phone'));
    $code = preg_replace('/\D/', '', (string) $req->get_param('code'));
    if (!$phone || strlen($code) < 4) return volo_err('Enter the code from the SMS');
    if (volo_limited('otp_check', 10, HOUR_IN_SECONDS, $phone)) return volo_err('Too many attempts. Request a new code later.', 429);
    $s = volo_settings();
    $ok = false;
    if ($s['test_code'] !== '' && hash_equals((string) $s['test_code'], $code)) {
        $ok = true;
    } elseif (volo_sms_ready()) {
        [$http, $j] = volo_twilio('/VerificationCheck', ['To' => $phone, 'Code' => $code]);
        $ok = $http >= 200 && $http < 300 && ($j['status'] ?? '') === 'approved';
    }
    if (!$ok) return volo_err('That code is not correct or has expired', 401);

    $u = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('users') . ' WHERE phone = %s', $phone), ARRAY_A);
    $new = false;
    if (!$u) {
        $wpdb->insert(volo_t('users'), ['phone' => $phone, 'tokens' => '[]', 'created' => volo_now(), 'last_seen' => volo_now()]);
        $u = volo_user($wpdb->insert_id);
        $new = true;
    }
    if (!$u) return volo_err('Could not create your account, please try again', 500);
    if ($u['blocked']) return volo_err('This number has been blocked', 403);
    $token = volo_issue_token($u);
    return volo_json(['token' => $token, 'new_user' => $new || $u['name'] === '', 'me' => volo_self(volo_user($u['id']))]);
}

function volo_r_auth_logout(WP_REST_Request $req) {
    global $wpdb;
    $u = volo_user_by_token($req->get_param('token'));
    if ($u) {
        $h = hash('sha256', (string) $req->get_param('token'));
        $list = array_values(array_filter(json_decode($u['tokens'], true) ?: [], function ($x) use ($h) { return $x !== $h; }));
        $wpdb->update(volo_t('users'), ['tokens' => wp_json_encode($list)], ['id' => $u['id']]);
        $fcm = (string) $req->get_param('fcm');
        if ($fcm !== '') $wpdb->delete(volo_t('push'), ['fcm' => $fcm]);
    }
    return volo_json([]);
}

function volo_r_me(WP_REST_Request $req) {
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    return volo_json(['me' => volo_self($me)]);
}

function volo_r_profile(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $upd = [];
    if (($n = $req->get_param('name')) !== null) {
        $n = mb_substr(sanitize_text_field((string) $n), 0, 40);
        if ($n === '') return volo_err('Please enter your name');
        $upd['name'] = $n;
    }
    if (($a = $req->get_param('about')) !== null) $upd['about'] = mb_substr(sanitize_text_field((string) $a), 0, 140);
    if (($un = $req->get_param('username')) !== null) {
        $un = strtolower(trim((string) $un, " @"));
        if ($un === '') {
            $upd['username'] = null;
        } else {
            if (!preg_match('/^[a-z0-9_.]{3,20}$/', $un)) return volo_err('Username: 3–20 letters, numbers, _ or .');
            $taken = $wpdb->get_var($wpdb->prepare('SELECT id FROM ' . volo_t('users') . ' WHERE username = %s AND id <> %d', $un, $me['id']));
            if ($taken) return volo_err('That username is taken', 409);
            $upd['username'] = $un;
        }
    }
    if (($av = $req->get_param('avatar')) !== null) {
        if ($av === '') {
            $upd['avatar'] = null;
        } else {
            $url = volo_store_image((string) $av, 'volo/avatars/u' . (int) $me['id']);
            if ($url instanceof WP_REST_Response) return $url;
            $upd['avatar'] = $url;
        }
    }
    if ($upd) $wpdb->update(volo_t('users'), $upd, ['id' => $me['id']]);
    return volo_json(['me' => volo_self(volo_user($me['id']))]);
}

// ---------------------------------------------------------------- email verification

function volo_r_email_send(WP_REST_Request $req) {
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $email = strtolower(trim(sanitize_email((string) $req->get_param('email'))));
    if (!is_email($email)) return volo_err('Please enter a valid email address');
    if (volo_limited('email_code', 6, HOUR_IN_SECONDS, (string) $me['id'])) return volo_err('Too many emails. Try again later.', 429);
    $code = (string) random_int(100000, 999999);
    set_transient('volo_email_' . $me['id'], ['email' => $email, 'hash' => wp_hash_password($code), 'tries' => 0], 20 * MINUTE_IN_SECONDS);
    $s = volo_settings();
    $name = $me['name'] !== '' ? $me['name'] : 'there';
    $html = '<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;border-radius:16px;background:#0D0B1E;color:#fff">'
        . '<h2 style="margin:0 0 8px;color:#2EE59D">Volo Chat</h2>'
        . '<p>Hi ' . esc_html($name) . ', your email verification code is:</p>'
        . '<p style="font-size:34px;letter-spacing:8px;font-weight:bold;margin:16px 0;color:#fff">' . $code . '</p>'
        . '<p style="color:#aaa;font-size:13px">It expires in 20 minutes. If you did not request this, ignore this email.</p></div>';
    $from = function () use ($s) { return $s['mail_from_name'] ?: 'Volo Chat'; };
    add_filter('wp_mail_from_name', $from);
    $sent = wp_mail($email, 'Your Volo Chat code: ' . $code, $html, ['Content-Type: text/html; charset=UTF-8']);
    remove_filter('wp_mail_from_name', $from);
    if (!$sent) return volo_err('The website could not send the email. (Admin: set up SMTP, e.g. the WP Mail SMTP plugin.)', 502);
    return volo_json(['sent' => true, 'email' => $email]);
}

function volo_r_email_verify(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $p = get_transient('volo_email_' . $me['id']);
    if (!is_array($p)) return volo_err('The code has expired — please send a new one', 410);
    $code = preg_replace('/\D/', '', (string) $req->get_param('code'));
    if (!wp_check_password($code, $p['hash'])) {
        $p['tries']++;
        if ($p['tries'] >= 6) {
            delete_transient('volo_email_' . $me['id']);
            return volo_err('Too many wrong codes — please send a new one', 429);
        }
        set_transient('volo_email_' . $me['id'], $p, 20 * MINUTE_IN_SECONDS);
        return volo_err('That code is not correct', 401);
    }
    delete_transient('volo_email_' . $me['id']);
    $wpdb->update(volo_t('users'), ['email' => $p['email'], 'email_verified' => 1], ['id' => $me['id']]);
    return volo_json(['me' => volo_self(volo_user($me['id']))]);
}

function volo_r_account_delete(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $id = (int) $me['id'];
    $wpdb->query($wpdb->prepare('DELETE FROM ' . volo_t('contacts') . ' WHERE a_id = %d OR b_id = %d', $id, $id));
    $wpdb->delete(volo_t('group_members'), ['user_id' => $id]);
    $wpdb->delete(volo_t('statuses'), ['user_id' => $id]);
    $wpdb->delete(volo_t('push'), ['member_key' => 'u:' . $id]);
    $wpdb->delete(volo_t('users'), ['id' => $id]);
    return volo_json([]);
}

// ================================================================ contacts

function volo_contact_row($me_id, $cid) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('contacts') . ' WHERE id = %d AND (a_id = %d OR b_id = %d)', $cid, $me_id, $me_id), ARRAY_A);
}

function volo_contact_between($a, $b) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('contacts') . ' WHERE a_id = %d AND b_id = %d', min($a, $b), max($a, $b)), ARRAY_A);
}

function volo_contact_payload($c, $me_id) {
    $other = ((int) $c['a_id'] === (int) $me_id) ? (int) $c['b_id'] : (int) $c['a_id'];
    $u = volo_user($other);
    if (!$u) return null;
    return ['cid' => (int) $c['id'], 'thread' => 'dm:' . (int) $c['id'], 'user' => volo_public($u)];
}

function volo_r_contacts_list(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('contacts') . ' WHERE (a_id = %d OR b_id = %d) AND status = %s ORDER BY id DESC LIMIT 1000', $me['id'], $me['id'], 'accepted'), ARRAY_A);
    $out = [];
    foreach ($rows as $c) if ($p = volo_contact_payload($c, $me['id'])) $out[] = $p;
    return volo_json(['me' => volo_self($me), 'contacts' => $out]);
}

/** Add someone by phone number, @username or email. Like WhatsApp, you can chat straight away. */
function volo_r_contacts_add(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    if (volo_limited('contact_add', 120, HOUR_IN_SECONDS, (string) $me['id'])) return volo_err('Too many requests', 429);
    $q = trim((string) $req->get_param('query'));
    if ($q === '') return volo_err('Enter a phone number, @username or email');
    $u = null;
    if (($ph = volo_phone($q)) !== null) {
        $u = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('users') . ' WHERE phone = %s', $ph), ARRAY_A);
    } elseif (is_email($q)) {
        $u = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('users') . ' WHERE email = %s AND email_verified = 1', strtolower($q)), ARRAY_A);
    } else {
        $u = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('users') . ' WHERE username = %s', strtolower(trim($q, ' @'))), ARRAY_A);
    }
    if (!$u || $u['name'] === '') return volo_err('No one on Volo Chat with that number/username yet — invite them!', 404);
    if ((int) $u['id'] === (int) $me['id']) return volo_err("That's you!");
    $c = volo_contact_between($me['id'], $u['id']);
    if (!$c) {
        $wpdb->insert(volo_t('contacts'), ['a_id' => min($me['id'], $u['id']), 'b_id' => max($me['id'], $u['id']), 'status' => 'accepted', 'added_by' => $me['id'], 'created' => volo_now()]);
        $c = volo_contact_between($me['id'], $u['id']);
    }
    return volo_json(['contact' => volo_contact_payload($c, $me['id'])]);
}

function volo_r_contacts_remove(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $c = volo_contact_row($me['id'], (int) $req->get_param('cid'));
    if (!$c) return volo_err('Not found', 404);
    $wpdb->delete(volo_t('contacts'), ['id' => $c['id']]);
    $wpdb->delete(volo_t('messages'), ['thread' => 'dm:' . (int) $c['id']]);
    return volo_json([]);
}

/** Which of these phone numbers (from the address book) use Volo Chat? */
function volo_r_contacts_match(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $phones = array_slice(array_values(array_unique(array_filter(array_map('volo_phone', (array) $req->get_param('phones'))))), 0, 2000);
    if (!$phones) return volo_json(['users' => []]);
    $out = [];
    foreach (array_chunk($phones, 200) as $chunk) {
        $in = implode(',', array_fill(0, count($chunk), '%s'));
        $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('users') . " WHERE phone IN ($in) AND name <> '' AND blocked = 0", $chunk), ARRAY_A);
        foreach ($rows as $u) if ((int) $u['id'] !== (int) $me['id']) $out[] = volo_public($u);
    }
    return volo_json(['users' => $out]);
}

// ================================================================ threads, chat, receipts

function volo_is_member($gid, $uid) {
    global $wpdb;
    return (bool) $wpdb->get_var($wpdb->prepare('SELECT 1 FROM ' . volo_t('group_members') . ' WHERE group_id = %d AND user_id = %d', $gid, $uid));
}

function volo_group_ids($uid) {
    global $wpdb;
    return array_map('intval', $wpdb->get_col($wpdb->prepare('SELECT group_id FROM ' . volo_t('group_members') . ' WHERE user_id = %d', $uid)));
}

/** Resolve the caller in a thread → [member_key, name, user_row] or error response. */
function volo_auth_thread(WP_REST_Request $req, $thread) {
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    if (strpos($thread, 'dm:') === 0) {
        if (!volo_contact_row($me['id'], (int) substr($thread, 3))) return volo_err('Not allowed in this chat', 403);
    } elseif (strpos($thread, 'grp:') === 0) {
        if (!volo_is_member((int) substr($thread, 4), (int) $me['id'])) return volo_err('You are not in this group', 403);
    } else {
        return volo_err('Unknown chat', 400);
    }
    return ['u:' . (int) $me['id'], $me['name'], $me];
}

/** Everyone in a thread: [member_key => name]. */
function volo_thread_members($thread) {
    global $wpdb;
    $out = [];
    if (strpos($thread, 'dm:') === 0) {
        $c = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('contacts') . ' WHERE id = %d', (int) substr($thread, 3)), ARRAY_A);
        if ($c) foreach ([(int) $c['a_id'], (int) $c['b_id']] as $uid) {
            $n = $wpdb->get_var($wpdb->prepare('SELECT name FROM ' . volo_t('users') . ' WHERE id = %d', $uid));
            if ($n !== null) $out['u:' . $uid] = $n;
        }
    } elseif (strpos($thread, 'grp:') === 0) {
        $rows = $wpdb->get_results($wpdb->prepare('SELECT u.id, u.name FROM ' . volo_t('group_members') . ' m JOIN ' . volo_t('users') . ' u ON u.id = m.user_id WHERE m.group_id = %d', (int) substr($thread, 4)), ARRAY_A);
        foreach ($rows as $r) $out['u:' . (int) $r['id']] = $r['name'];
    }
    return $out;
}

function volo_thread_others($thread, $key) {
    $m = volo_thread_members($thread);
    unset($m[$key]);
    return array_keys($m);
}

function volo_mark($thread, $key, $delivered, $seen) {
    global $wpdb;
    if ($key === '' || $thread === '') return;
    $wpdb->query($wpdb->prepare(
        'INSERT INTO ' . volo_t('reads') . ' (thread, member_key, delivered, seen, typing_until) VALUES (%s, %s, %d, %d, 0)
         ON DUPLICATE KEY UPDATE delivered = GREATEST(delivered, VALUES(delivered)), seen = GREATEST(seen, VALUES(seen))',
        $thread, $key, max((int) $delivered, (int) $seen), (int) $seen
    ));
}

function volo_peer_state($thread, $key) {
    global $wpdb;
    $others = volo_thread_members($thread);
    unset($others[$key]);
    if (!$others) return ['peer_delivered' => 0, 'peer_seen' => 0, 'typing' => []];
    $in = implode(',', array_fill(0, count($others), '%s'));
    $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('reads') . " WHERE thread = %s AND member_key IN ($in)", array_merge([$thread], array_keys($others))), ARRAY_A);
    $by = [];
    foreach ($rows as $r) $by[$r['member_key']] = $r;
    $del = PHP_INT_MAX; $seen = PHP_INT_MAX; $typing = [];
    foreach ($others as $k => $name) {
        $r = $by[$k] ?? null;
        $del = min($del, $r ? (int) $r['delivered'] : 0);
        $seen = min($seen, $r ? (int) $r['seen'] : 0);
        if ($r && (int) $r['typing_until'] > volo_now()) $typing[] = $name;
    }
    return ['peer_delivered' => $del, 'peer_seen' => $seen, 'typing' => $typing];
}

function volo_format($m, $my_key) {
    $body = $m['body'];
    $dec = in_array($m['type'], ['location', 'call', 'voice', 'sos', 'meet', 'system', 'image', 'reply'], true) ? json_decode($body, true) : null;
    return [
        'id' => (int) $m['id'], 'type' => $m['type'], 'body' => $dec !== null ? $dec : $body,
        'name' => $m['sender_name'], 'sender' => $m['sender_key'], 'mine' => $m['sender_key'] === $my_key, 'ts' => (int) $m['created'],
    ];
}

function volo_insert_message($thread, $who, $type, $body) {
    global $wpdb;
    $wpdb->insert(volo_t('messages'), ['thread' => $thread, 'sender_key' => $who[0], 'sender_name' => $who[1], 'type' => $type, 'body' => $body, 'created' => volo_now()]);
    return (int) $wpdb->insert_id;
}

function volo_r_chat_send(WP_REST_Request $req) {
    global $wpdb;
    if (volo_limited('chat_send', 900, HOUR_IN_SECONDS)) return volo_err('Too many messages, slow down', 429);
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $type = (string) $req->get_param('type');
    if (!in_array($type, ['text', 'image', 'location', 'voice'], true)) $type = 'text';
    $reply = (int) $req->get_param('reply_to');
    if ($type === 'image') {
        $url = volo_store_image((string) $req->get_param('image'), 'volo/chat/' . md5($thread));
        if ($url instanceof WP_REST_Response) return $url;
        $body = wp_json_encode(['url' => $url, 'caption' => mb_substr(sanitize_text_field((string) $req->get_param('caption')), 0, 500)]);
    } elseif ($type === 'voice') {
        $url = volo_store_audio((string) $req->get_param('audio'), 'volo/chat/v' . md5($thread));
        if ($url instanceof WP_REST_Response) return $url;
        $body = wp_json_encode(['url' => $url, 'dur' => max(0, min(600, (int) $req->get_param('duration')))]);
    } elseif ($type === 'location') {
        $b = (array) $req->get_param('body');
        $body = wp_json_encode(['lat' => (float) ($b['lat'] ?? 0), 'lng' => (float) ($b['lng'] ?? 0)]);
    } else {
        $text = trim(wp_strip_all_tags((string) $req->get_param('body')));
        if ($text === '') return volo_err('Empty message');
        $text = mb_substr($text, 0, 4000);
        if ($reply > 0) {
            $orig = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('messages') . ' WHERE id = %d AND thread = %s', $reply, $thread), ARRAY_A);
            if ($orig) {
                $prev = $orig['type'] === 'text' ? mb_substr($orig['body'], 0, 120) : ucfirst($orig['type']);
                $type = 'reply';
                $text = wp_json_encode(['text' => $text, 'reply_to' => $reply, 'quote' => $prev, 'quote_name' => $orig['sender_name']]);
            }
        }
        $body = $text;
    }
    $id = volo_insert_message($thread, $who, $type, $body);
    volo_mark($thread, $who[0], $id, $id);
    volo_push_message($thread, $who, $type, $body);
    $m = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('messages') . ' WHERE id = %d', $id), ARRAY_A);
    return volo_json(['message' => volo_format($m, $who[0])]);
}

function volo_r_chat_delete(WP_REST_Request $req) {
    global $wpdb;
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $m = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('messages') . ' WHERE id = %d AND thread = %s', (int) $req->get_param('id'), $thread), ARRAY_A);
    if (!$m || $m['sender_key'] !== $who[0]) return volo_err('You can only delete your own messages', 403);
    $wpdb->update(volo_t('messages'), ['type' => 'deleted', 'body' => ''], ['id' => $m['id']]);
    return volo_json([]);
}

function volo_r_chat_poll(WP_REST_Request $req) {
    global $wpdb;
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $after = (int) $req->get_param('after');
    if ($after > 0) {
        $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('messages') . ' WHERE thread = %s AND id > %d ORDER BY id ASC LIMIT 300', $thread, $after), ARRAY_A);
    } else {
        $rows = array_reverse($wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('messages') . ' WHERE thread = %s ORDER BY id DESC LIMIT 150', $thread), ARRAY_A));
    }
    // ids deleted since last poll (shown as "This message was deleted")
    $deleted = array_map('intval', $wpdb->get_col($wpdb->prepare("SELECT id FROM " . volo_t('messages') . " WHERE thread = %s AND type = 'deleted' AND id <= %d ORDER BY id DESC LIMIT 100", $thread, $after)));
    $out = array_map(function ($m) use ($who) { return volo_format($m, $who[0]); }, $rows);
    $newest = (int) $wpdb->get_var($wpdb->prepare('SELECT MAX(id) FROM ' . volo_t('messages') . ' WHERE thread = %s', $thread));
    volo_mark($thread, $who[0], $newest, min((int) $req->get_param('seen'), $newest));
    $peer = [];
    if (strpos($thread, 'dm:') === 0) {
        foreach (volo_thread_others($thread, $who[0]) as $k) {
            $u = volo_user((int) substr($k, 2));
            if ($u) $peer = ['online' => volo_now() - (int) $u['last_seen'] < 45, 'last_seen' => (int) $u['last_seen']];
        }
    }
    return volo_json(['messages' => $out, 'deleted' => $deleted, 'meet' => volo_meet_load($thread), 'peer' => $peer] + volo_peer_state($thread, $who[0]));
}

function volo_r_chat_typing(WP_REST_Request $req) {
    global $wpdb;
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $until = $req->get_param('typing') ? volo_now() + 6 : 0;
    $wpdb->query($wpdb->prepare('INSERT INTO ' . volo_t('reads') . ' (thread, member_key, delivered, seen, typing_until) VALUES (%s, %s, 0, 0, %d) ON DUPLICATE KEY UPDATE typing_until = VALUES(typing_until)', $thread, $who[0], $until));
    return volo_json([]);
}

/** Chat list: latest message per thread, unread counts, ringing calls, contacts' presence. */
function volo_r_chat_inbox(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $mk = 'u:' . (int) $me['id'];
    $threads = [];
    foreach ($wpdb->get_col($wpdb->prepare("SELECT id FROM " . volo_t('contacts') . " WHERE (a_id = %d OR b_id = %d) AND status = 'accepted'", $me['id'], $me['id'])) as $cid) $threads[] = 'dm:' . (int) $cid;
    foreach (volo_group_ids((int) $me['id']) as $gid) $threads[] = 'grp:' . $gid;
    $latest = []; $unread = [];
    if ($threads) {
        $in = implode(',', array_fill(0, count($threads), '%s'));
        $reads = [];
        foreach ($wpdb->get_results($wpdb->prepare('SELECT thread, seen FROM ' . volo_t('reads') . " WHERE member_key = %s AND thread IN ($in)", array_merge([$mk], $threads)), ARRAY_A) as $r) $reads[$r['thread']] = (int) $r['seen'];
        foreach ($threads as $th) {
            $m = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('messages') . ' WHERE thread = %s ORDER BY id DESC LIMIT 1', $th), ARRAY_A);
            if (!$m) continue;
            $latest[$th] = volo_format($m, $mk);
            $unread[$th] = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . volo_t('messages') . ' WHERE thread = %s AND id > %d AND sender_key <> %s AND type <> %s', $th, $reads[$th] ?? 0, $mk, 'system'));
            volo_mark($th, $mk, (int) $m['id'], 0); // delivered to this phone
        }
    }
    $ringing = [];
    if ($threads) {
        $in = implode(',', array_fill(0, count($threads), '%s'));
        $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('calls') . " WHERE status = 'ringing' AND created >= %d AND thread IN ($in) ORDER BY id DESC LIMIT 5", array_merge([volo_now() - 45], $threads)), ARRAY_A);
        foreach ($rows as $c) {
            if ($c['caller_key'] === $mk) continue;
            $cu = volo_user((int) substr($c['caller_key'], 2));
            $ringing[] = ['thread' => $c['thread'], 'call_id' => $c['call_id'], 'video' => (bool) $c['video'], 'caller_name' => $c['caller_name'], 'caller_avatar' => $cu['avatar'] ?? null, 'age' => volo_now() - (int) $c['created']];
        }
    }
    return volo_json(['latest' => (object) $latest, 'unread' => (object) $unread, 'ringing' => $ringing, 'now' => volo_now()]);
}

// ================================================================ calls (WebRTC signaling, non-trickle ICE)

function volo_call_load($thread, $id) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('calls') . ' WHERE call_id = %s AND thread = %s', $id, $thread), ARRAY_A);
}

function volo_call_state($c, $key) {
    $st = $c['status'];
    if ($st === 'ringing' && volo_now() - (int) $c['created'] > 60) $st = 'missed';
    return [
        'call_id' => $c['call_id'], 'status' => $st, 'video' => (bool) $c['video'], 'caller_name' => $c['caller_name'],
        'i_am_caller' => $c['caller_key'] === $key,
        'offer' => $c['offer'] ? json_decode($c['offer'], true) : null,
        'answer' => $c['answer'] ? json_decode($c['answer'], true) : null,
        'created' => (int) $c['created'],
    ];
}

function volo_r_call_start(WP_REST_Request $req) {
    global $wpdb;
    if (volo_limited('call_start', 150, HOUR_IN_SECONDS)) return volo_err('Too many calls, please wait', 429);
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    if (strpos($thread, 'dm:') !== 0) return volo_err('Group calls are not available yet');
    $offer = $req->get_param('offer');
    if (!is_array($offer) || empty($offer['sdp'])) return volo_err('Missing call offer');
    $video = (bool) $req->get_param('video');
    $theirs = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('calls') . " WHERE thread = %s AND status = 'ringing' AND caller_key <> %s AND created >= %d ORDER BY id DESC LIMIT 1", $thread, $who[0], volo_now() - 45), ARRAY_A);
    if ($theirs) return volo_json(['join' => $theirs['call_id'], 'video' => (bool) $theirs['video']]);
    $live = $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . volo_t('calls') . " WHERE thread = %s AND status = 'active' AND updated >= %d", $thread, volo_now() - 90));
    if ($live) return volo_json(['busy' => true]);
    $call_id = strtolower(wp_generate_password(16, false, false));
    $now = volo_now();
    $wpdb->insert(volo_t('calls'), [
        'call_id' => $call_id, 'thread' => $thread, 'caller_key' => $who[0], 'caller_name' => $who[1], 'video' => $video ? 1 : 0, 'status' => 'ringing',
        'offer' => wp_json_encode(['type' => (string) ($offer['type'] ?? 'offer'), 'sdp' => (string) $offer['sdp']]), 'answer' => null, 'created' => $now, 'updated' => $now,
    ]);
    volo_insert_message($thread, $who, 'call', wp_json_encode(['call_id' => $call_id, 'video' => $video]));
    volo_push_send(volo_thread_others($thread, $who[0]), [
        'type' => 'call', 'thread' => $thread, 'call_id' => $call_id, 'video' => $video ? '1' : '0', 'caller' => $who[1],
    ], ($video ? '📹 ' : '📞 ') . $who[1], $video ? 'Incoming video call' : 'Incoming voice call', true);
    return volo_json(['call_id' => $call_id]);
}

function volo_r_call_get(WP_REST_Request $req) {
    global $wpdb;
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $c = volo_call_load($thread, (string) $req->get_param('call_id'));
    if (!$c) return volo_err('Call not found', 404);
    if ($c['status'] === 'active' && volo_now() - (int) $c['updated'] > 20) $wpdb->update(volo_t('calls'), ['updated' => volo_now()], ['id' => $c['id']]);
    return volo_json(['call' => volo_call_state($c, $who[0])]);
}

function volo_r_call_answer(WP_REST_Request $req) {
    global $wpdb;
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $c = volo_call_load($thread, (string) $req->get_param('call_id'));
    if (!$c) return volo_err('Call not found', 404);
    if ($c['caller_key'] === $who[0]) return volo_err('You started this call');
    if ($c['status'] !== 'ringing') return volo_err('This call has already ended', 409);
    $a = $req->get_param('answer');
    if (!is_array($a) || empty($a['sdp'])) return volo_err('Missing answer');
    $wpdb->update(volo_t('calls'), ['answer' => wp_json_encode(['type' => (string) ($a['type'] ?? 'answer'), 'sdp' => (string) $a['sdp']]), 'status' => 'active', 'updated' => volo_now(), 'answered' => volo_now()], ['id' => $c['id']]);
    return volo_json([]);
}

function volo_r_call_end(WP_REST_Request $req) {
    global $wpdb;
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    $c = volo_call_load($thread, (string) $req->get_param('call_id'));
    if (!$c) return volo_err('Call not found', 404);
    $st = in_array($req->get_param('status'), ['declined', 'busy'], true) ? $req->get_param('status') : 'ended';
    $upd = ['updated' => volo_now()];
    if (in_array($c['status'], ['ringing', 'active'], true)) {
        $upd['status'] = $c['status'] === 'active' ? 'ended' : $st;
        $upd['ended'] = volo_now();
    }
    $wpdb->update(volo_t('calls'), $upd, ['id' => $c['id']]);
    return volo_json([]);
}

function volo_r_call_history(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $mk = 'u:' . (int) $me['id'];
    $map = [];
    foreach ($wpdb->get_results($wpdb->prepare("SELECT * FROM " . volo_t('contacts') . " WHERE (a_id = %d OR b_id = %d) AND status = 'accepted'", $me['id'], $me['id']), ARRAY_A) as $c) {
        $p = volo_contact_payload($c, $me['id']);
        if ($p) $map[$p['thread']] = $p['user'];
    }
    if (!$map) return volo_json(['calls' => []]);
    $in = implode(',', array_fill(0, count($map), '%s'));
    $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('calls') . " WHERE thread IN ($in) ORDER BY id DESC LIMIT 200", array_keys($map)), ARRAY_A);
    $out = [];
    foreach ($rows as $c) {
        $st = $c['status'];
        if ($st === 'ringing' && volo_now() - (int) $c['created'] > 60) $st = 'missed';
        $ans = (int) $c['answered'];
        $end = (int) $c['ended'] ?: ($st === 'ended' || $st === 'active' ? (int) $c['updated'] : 0);
        $u = $map[$c['thread']];
        $out[] = [
            'call_id' => $c['call_id'], 'thread' => $c['thread'], 'video' => (bool) $c['video'], 'outgoing' => $c['caller_key'] === $mk,
            'peer' => $u['name'], 'avatar' => $u['avatar'], 'status' => $ans > 0 ? 'answered' : $st,
            'ts' => (int) $c['created'], 'duration' => ($ans > 0 && $end > $ans) ? $end - $ans : 0,
        ];
    }
    return volo_json(['calls' => $out]);
}

// ================================================================ groups

function volo_group_payload($g) {
    global $wpdb;
    $rows = $wpdb->get_results($wpdb->prepare('SELECT u.* FROM ' . volo_t('group_members') . ' m JOIN ' . volo_t('users') . ' u ON u.id = m.user_id WHERE m.group_id = %d ORDER BY m.joined', (int) $g['id']), ARRAY_A);
    return ['id' => (int) $g['id'], 'name' => $g['name'], 'owner' => (int) $g['owner_id'], 'avatar' => $g['avatar'] ?: null, 'thread' => 'grp:' . (int) $g['id'], 'members' => array_map('volo_public', $rows)];
}

function volo_group_system($gid, $text) {
    volo_insert_message('grp:' . (int) $gid, ['sys', ''], 'system', wp_json_encode(['text' => $text]));
}

function volo_r_groups_create(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    if (volo_limited('grp_create', 30, HOUR_IN_SECONDS)) return volo_err('Too many requests', 429);
    $name = mb_substr(sanitize_text_field((string) $req->get_param('name')), 0, 60);
    if ($name === '') return volo_err('Give the group a name');
    $wpdb->insert(volo_t('groups'), ['name' => $name, 'owner_id' => $me['id'], 'created' => volo_now()]);
    $gid = (int) $wpdb->insert_id;
    if (!$gid) return volo_err('Could not create the group', 500);
    $wpdb->insert(volo_t('group_members'), ['group_id' => $gid, 'user_id' => $me['id'], 'joined' => volo_now()]);
    foreach (array_slice(array_unique(array_map('intval', (array) $req->get_param('members'))), 0, 256) as $uid) {
        if ($uid && $uid !== (int) $me['id'] && volo_contact_between($me['id'], $uid)) {
            $wpdb->insert(volo_t('group_members'), ['group_id' => $gid, 'user_id' => $uid, 'joined' => volo_now()]);
        }
    }
    volo_group_system($gid, $me['name'] . ' created the group "' . $name . '"');
    return volo_json(['group' => volo_group_payload($wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('groups') . ' WHERE id = %d', $gid), ARRAY_A))]);
}

function volo_r_groups_list(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $out = [];
    foreach (volo_group_ids((int) $me['id']) as $gid) {
        $g = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('groups') . ' WHERE id = %d', $gid), ARRAY_A);
        if ($g) $out[] = volo_group_payload($g);
    }
    return volo_json(['groups' => $out]);
}

function volo_r_groups_add(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $gid = (int) $req->get_param('group_id');
    if (!volo_is_member($gid, (int) $me['id'])) return volo_err('You are not in this group', 403);
    $added = [];
    foreach (array_unique(array_map('intval', (array) $req->get_param('members'))) as $uid) {
        if (!$uid || volo_is_member($gid, $uid) || !volo_contact_between($me['id'], $uid)) continue;
        $wpdb->insert(volo_t('group_members'), ['group_id' => $gid, 'user_id' => $uid, 'joined' => volo_now()]);
        $u = volo_user($uid);
        if ($u) $added[] = $u['name'];
    }
    if ($added) volo_group_system($gid, $me['name'] . ' added ' . implode(', ', $added));
    return volo_json(['group' => volo_group_payload($wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('groups') . ' WHERE id = %d', $gid), ARRAY_A))]);
}

function volo_r_groups_leave(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $gid = (int) $req->get_param('group_id');
    $wpdb->delete(volo_t('group_members'), ['group_id' => $gid, 'user_id' => $me['id']]);
    if ((int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . volo_t('group_members') . ' WHERE group_id = %d', $gid)) === 0) {
        $wpdb->delete(volo_t('groups'), ['id' => $gid]);
        $wpdb->delete(volo_t('messages'), ['thread' => 'grp:' . $gid]);
        delete_option('volo_meet_' . md5('grp:' . $gid));
    } else {
        volo_group_system($gid, $me['name'] . ' left');
    }
    return volo_json([]);
}

function volo_r_groups_locations(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $gid = (int) $req->get_param('group_id');
    if (!volo_is_member($gid, (int) $me['id'])) return volo_err('You are not in this group', 403);
    $rows = $wpdb->get_results($wpdb->prepare('SELECT u.* FROM ' . volo_t('group_members') . ' m JOIN ' . volo_t('users') . ' u ON u.id = m.user_id WHERE m.group_id = %d', $gid), ARRAY_A);
    $out = [];
    foreach ($rows as $r) {
        $has = $r['loc_share'] && $r['loc_lat'] !== null;
        $out[] = volo_public($r) + [
            'me' => (int) $r['id'] === (int) $me['id'], 'sharing' => (bool) $r['loc_share'],
            'lat' => $has ? (float) $r['loc_lat'] : null, 'lng' => $has ? (float) $r['loc_lng'] : null,
            'acc' => $has && $r['loc_acc'] !== null ? (float) $r['loc_acc'] : null, 'loc_at' => (int) $r['loc_at'],
        ];
    }
    return volo_json(['members' => $out, 'meet' => volo_meet_load('grp:' . $gid), 'now' => volo_now()]);
}

function volo_r_loc_update(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $share = (bool) $req->get_param('share');
    $upd = ['loc_share' => $share ? 1 : 0];
    $lat = $req->get_param('lat'); $lng = $req->get_param('lng');
    if ($share && is_numeric($lat) && is_numeric($lng) && abs((float) $lat) <= 90 && abs((float) $lng) <= 180) {
        $upd += ['loc_lat' => (float) $lat, 'loc_lng' => (float) $lng, 'loc_acc' => is_numeric($req->get_param('acc')) ? (float) $req->get_param('acc') : null, 'loc_at' => volo_now()];
    }
    if (!$share) $upd += ['loc_lat' => null, 'loc_lng' => null, 'loc_acc' => null];
    $wpdb->update(volo_t('users'), $upd, ['id' => $me['id']]);
    return volo_json([]);
}

// ---------------------------------------------------------------- meeting point

function volo_meet_load($thread) {
    $m = get_option('volo_meet_' . md5($thread));
    return is_array($m) ? $m : null;
}

function volo_r_meet_set(WP_REST_Request $req) {
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    if ($req->get_param('clear')) {
        delete_option('volo_meet_' . md5($thread));
        return volo_json(['meet' => null]);
    }
    $lat = $req->get_param('lat'); $lng = $req->get_param('lng');
    if (!is_numeric($lat) || !is_numeric($lng)) return volo_err('Pick a spot on the map');
    $meet = ['lat' => (float) $lat, 'lng' => (float) $lng, 'label' => mb_substr(sanitize_text_field((string) $req->get_param('label')), 0, 80), 'by' => $who[1], 'ts' => volo_now()];
    update_option('volo_meet_' . md5($thread), $meet, false);
    $body = wp_json_encode($meet);
    volo_insert_message($thread, $who, 'meet', $body);
    volo_push_message($thread, $who, 'meet', $body);
    return volo_json(['meet' => $meet]);
}

function volo_r_meet_get(WP_REST_Request $req) {
    $thread = volo_thread_param($req);
    $who = volo_auth_thread($req, $thread);
    if ($who instanceof WP_REST_Response) return $who;
    return volo_json(['meet' => volo_meet_load($thread)]);
}

// ---------------------------------------------------------------- SOS

function volo_r_sos_send(WP_REST_Request $req) {
    if (volo_limited('sos', 30, HOUR_IN_SECONDS)) return volo_err('Too many SOS alerts — please call directly', 429);
    $threads = array_slice(array_unique(array_map(function ($t) { return substr(preg_replace('/[^A-Za-z0-9:_-]/', '', (string) $t), 0, 60); }, (array) $req->get_param('threads'))), 0, 50);
    if (!$threads) return volo_err('No one to alert — add contacts or a family group first');
    $audio = null;
    if (($b64 = (string) $req->get_param('audio')) !== '') {
        $a = volo_store_audio($b64, 'volo/sos');
        if (!($a instanceof WP_REST_Response)) $audio = $a;
    }
    $lat = $req->get_param('lat'); $lng = $req->get_param('lng');
    $body = wp_json_encode(['lat' => is_numeric($lat) ? (float) $lat : null, 'lng' => is_numeric($lng) ? (float) $lng : null, 'acc' => is_numeric($req->get_param('acc')) ? (float) $req->get_param('acc') : null, 'audio' => $audio]);
    $sent = 0;
    foreach ($threads as $th) {
        $who = volo_auth_thread($req, $th);
        if ($who instanceof WP_REST_Response) continue;
        volo_insert_message($th, $who, 'sos', $body);
        volo_push_message($th, $who, 'sos', $body);
        $sent++;
    }
    if (!$sent) return volo_err('Could not send the alert — please sign in again', 403);
    return volo_json(['sent' => $sent]);
}

// ================================================================ Status (24-hour stories)

function volo_r_status_post(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    if (volo_limited('status_post', 60, DAY_IN_SECONDS, (string) $me['id'])) return volo_err('Too many status updates today', 429);
    $type = $req->get_param('type') === 'image' ? 'image' : 'text';
    $caption = mb_substr(sanitize_text_field((string) $req->get_param('caption')), 0, 300);
    if ($type === 'image') {
        $url = volo_store_image((string) $req->get_param('image'), 'volo/status/u' . (int) $me['id']);
        if ($url instanceof WP_REST_Response) return $url;
        $body = $url;
    } else {
        $body = mb_substr(trim(sanitize_textarea_field((string) $req->get_param('text'))), 0, 700);
        if ($body === '') return volo_err('Write something for your status');
    }
    $bg = preg_match('/^#[0-9A-Fa-f]{6}$/', (string) $req->get_param('bg')) ? (string) $req->get_param('bg') : '#6C4CF1';
    $wpdb->insert(volo_t('statuses'), ['user_id' => $me['id'], 'type' => $type, 'body' => $body, 'bg' => $bg, 'caption' => $caption, 'created' => volo_now()]);
    return volo_json(['id' => (int) $wpdb->insert_id]);
}

function volo_status_item($s, $viewed = false) {
    return ['id' => (int) $s['id'], 'type' => $s['type'], 'body' => $s['body'], 'bg' => $s['bg'], 'caption' => $s['caption'], 'ts' => (int) $s['created'], 'viewed' => (bool) $viewed];
}

/** My statuses + my contacts' statuses from the last 24 hours. */
function volo_r_status_feed(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $since = volo_now() - VOLO_STATUS_TTL;
    $mine = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('statuses') . ' WHERE user_id = %d AND created >= %d ORDER BY id ASC', $me['id'], $since), ARRAY_A);
    $my_items = [];
    foreach ($mine as $s) {
        $views = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . volo_t('status_views') . ' WHERE status_id = %d', $s['id']));
        $my_items[] = volo_status_item($s, true) + ['views' => $views];
    }
    $ids = [];
    foreach ($wpdb->get_results($wpdb->prepare("SELECT * FROM " . volo_t('contacts') . " WHERE (a_id = %d OR b_id = %d) AND status = 'accepted'", $me['id'], $me['id']), ARRAY_A) as $c) {
        $ids[] = ((int) $c['a_id'] === (int) $me['id']) ? (int) $c['b_id'] : (int) $c['a_id'];
    }
    $people = [];
    if ($ids) {
        $in = implode(',', array_fill(0, count($ids), '%d'));
        $rows = $wpdb->get_results($wpdb->prepare('SELECT s.*, v.viewed AS seen_at FROM ' . volo_t('statuses') . ' s LEFT JOIN ' . volo_t('status_views') . " v ON v.status_id = s.id AND v.viewer_id = %d WHERE s.user_id IN ($in) AND s.created >= %d ORDER BY s.id ASC", array_merge([$me['id']], $ids, [$since])), ARRAY_A);
        foreach ($rows as $s) {
            $uid = (int) $s['user_id'];
            if (!isset($people[$uid])) {
                $u = volo_user($uid);
                if (!$u) continue;
                $people[$uid] = ['user' => volo_public($u), 'items' => []];
            }
            $people[$uid]['items'][] = volo_status_item($s, $s['seen_at'] !== null);
        }
    }
    $list = array_values($people);
    usort($list, function ($a, $b) { return end($b['items'])['ts'] <=> end($a['items'])['ts']; });
    return volo_json(['mine' => $my_items, 'me' => volo_public($me), 'people' => $list]);
}

function volo_r_status_view(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $id = (int) $req->get_param('status_id');
    $s = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . volo_t('statuses') . ' WHERE id = %d', $id), ARRAY_A);
    if (!$s || (int) $s['user_id'] === (int) $me['id'] || !volo_contact_between($me['id'], $s['user_id'])) return volo_json([]);
    $wpdb->query($wpdb->prepare('INSERT IGNORE INTO ' . volo_t('status_views') . ' (status_id, viewer_id, viewed) VALUES (%d, %d, %d)', $id, $me['id'], volo_now()));
    return volo_json([]);
}

function volo_r_status_viewers(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $id = (int) $req->get_param('status_id');
    $own = $wpdb->get_var($wpdb->prepare('SELECT 1 FROM ' . volo_t('statuses') . ' WHERE id = %d AND user_id = %d', $id, $me['id']));
    if (!$own) return volo_err('Not found', 404);
    $rows = $wpdb->get_results($wpdb->prepare('SELECT u.*, v.viewed AS viewed_at FROM ' . volo_t('status_views') . ' v JOIN ' . volo_t('users') . ' u ON u.id = v.viewer_id WHERE v.status_id = %d ORDER BY v.viewed DESC', $id), ARRAY_A);
    return volo_json(['viewers' => array_map(function ($r) { return volo_public($r) + ['viewed_at' => (int) $r['viewed_at']]; }, $rows)]);
}

function volo_r_status_delete(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $id = (int) $req->get_param('status_id');
    $wpdb->delete(volo_t('statuses'), ['id' => $id, 'user_id' => $me['id']]);
    $wpdb->delete(volo_t('status_views'), ['status_id' => $id]);
    return volo_json([]);
}

// ================================================================ push notifications (optional, FCM HTTP v1)

function volo_r_push_register(WP_REST_Request $req) {
    global $wpdb;
    $me = volo_me($req);
    if ($me instanceof WP_REST_Response) return $me;
    $fcm = substr(preg_replace('/[^A-Za-z0-9:_\-.]/', '', (string) $req->get_param('fcm')), 0, 250);
    if (strlen($fcm) < 20) return volo_err('Invalid push token');
    $wpdb->delete(volo_t('push'), ['fcm' => $fcm]);
    $wpdb->insert(volo_t('push'), ['member_key' => 'u:' . (int) $me['id'], 'fcm' => $fcm, 'platform' => $req->get_param('platform') === 'ios' ? 'ios' : 'android', 'updated' => volo_now()]);
    return volo_json([]);
}

function volo_b64url($s) { return rtrim(strtr(base64_encode($s), '+/', '-_'), '='); }

function volo_push_token() {
    if ($t = get_transient('volo_push_oauth')) return $t;
    $sa = json_decode((string) volo_settings()['fcm_service_json'], true);
    if (!is_array($sa) || empty($sa['private_key']) || empty($sa['client_email']) || !function_exists('openssl_sign')) return null;
    $now = time();
    $h = volo_b64url(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $c = volo_b64url(wp_json_encode(['iss' => $sa['client_email'], 'scope' => 'https://www.googleapis.com/auth/firebase.messaging', 'aud' => 'https://oauth2.googleapis.com/token', 'iat' => $now, 'exp' => $now + 3600]));
    $sig = '';
    if (!openssl_sign($h . '.' . $c, $sig, $sa['private_key'], 'sha256WithRSAEncryption')) return null;
    $r = wp_remote_post('https://oauth2.googleapis.com/token', ['timeout' => 10, 'body' => ['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => $h . '.' . $c . '.' . volo_b64url($sig)]]);
    if (is_wp_error($r)) return null;
    $j = json_decode(wp_remote_retrieve_body($r), true);
    if (empty($j['access_token'])) return null;
    set_transient('volo_push_oauth', $j['access_token'], 50 * MINUTE_IN_SECONDS);
    return $j['access_token'];
}

function volo_push_send($keys, $data, $title, $body, $urgent = false) {
    global $wpdb;
    if (!$keys) return;
    $s = volo_settings();
    if ($s['fcm_project_id'] === '' || $s['fcm_service_json'] === '') return;
    $in = implode(',', array_fill(0, count($keys), '%s'));
    $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . volo_t('push') . " WHERE member_key IN ($in)", $keys), ARRAY_A);
    if (!$rows || !($at = volo_push_token())) return;
    $data = array_map('strval', $data + ['title' => $title, 'body' => $body]);
    $isCall = ($data['type'] ?? '') === 'call';
    foreach ($rows as $row) {
        $msg = ['token' => $row['fcm'], 'data' => $data];
        if ($row['platform'] === 'ios') {
            $msg['apns'] = ['headers' => ['apns-priority' => '10', 'apns-push-type' => 'alert'], 'payload' => ['aps' => ['alert' => ['title' => $title, 'body' => $body], 'sound' => 'default', 'interruption-level' => $urgent ? 'time-sensitive' : 'active']]];
        } else {
            $msg['android'] = ['priority' => $urgent ? 'HIGH' : 'NORMAL', 'ttl' => $isCall ? '45s' : '86400s'];
            if (!$isCall) $msg['android']['notification'] = ['title' => $title, 'body' => $body, 'sound' => 'default', 'channel_id' => $urgent ? 'volo_sos' : 'volo_messages', 'tag' => $data['thread'] ?? 'volo'];
        }
        $r = wp_remote_post('https://fcm.googleapis.com/v1/projects/' . rawurlencode($s['fcm_project_id']) . '/messages:send', [
            'timeout' => $urgent ? 6 : 4, 'headers' => ['Authorization' => 'Bearer ' . $at, 'Content-Type' => 'application/json'], 'body' => wp_json_encode(['message' => $msg]),
        ]);
        if (!is_wp_error($r) && in_array((int) wp_remote_retrieve_response_code($r), [400, 404], true) && strpos(wp_remote_retrieve_body($r), 'UNREGISTERED') !== false) {
            $wpdb->delete(volo_t('push'), ['id' => $row['id']]);
        }
    }
}

function volo_push_message($thread, $who, $type, $body) {
    global $wpdb;
    $others = volo_thread_others($thread, $who[0]);
    if (!$others) return;
    $title = $who[1];
    if (strpos($thread, 'grp:') === 0) {
        $g = $wpdb->get_var($wpdb->prepare('SELECT name FROM ' . volo_t('groups') . ' WHERE id = %d', (int) substr($thread, 4)));
        if ($g) $title = $who[1] . ' @ ' . $g;
    }
    $text = $type === 'reply' ? ((json_decode($body, true)['text'] ?? '')) : $body;
    $preview = ['text' => mb_substr((string) $text, 0, 140), 'reply' => mb_substr((string) $text, 0, 140), 'image' => '📷 Photo', 'location' => '📍 Location', 'voice' => '🎤 Voice message', 'meet' => '📌 Meeting point'][$type] ?? 'New message';
    $urgent = $type === 'sos';
    if ($urgent) { $title = '🚨 SOS — ' . $who[1] . ' needs help'; $preview = 'Tap to see their location'; }
    volo_push_send($others, ['type' => $type, 'thread' => $thread, 'sender' => $who[1]], $title, $preview, $urgent);
}

// ================================================================ admin

add_action('admin_menu', function () {
    add_options_page('Volo Chat', 'Volo Chat', 'manage_options', 'volo-chat', 'volo_admin_settings');
    add_users_page('Volo Chat Users', 'Volo Chat Users', 'manage_options', 'volo-chat-users', 'volo_admin_users');
});

function volo_admin_settings() {
    if (!current_user_can('manage_options')) return;
    $s = volo_settings();
    if (isset($_POST['volo_save']) && check_admin_referer('volo_admin')) {
        $keys = ['twilio_sid', 'twilio_token', 'twilio_verify_sid', 'test_code', 'stun_url', 'turn_url', 'turn_username', 'turn_credential',
                 'fcm_api_key', 'fcm_project_id', 'fcm_sender_id', 'fcm_android_app_id', 'fcm_ios_app_id', 'mail_from_name'];
        $new = $s;
        foreach ($keys as $k) $new[$k] = sanitize_text_field(wp_unslash($_POST[$k] ?? ''));
        $new['test_code'] = preg_replace('/\D/', '', $new['test_code']);
        $new['require_email'] = empty($_POST['require_email']) ? 0 : 1;
        $sj = trim(wp_unslash($_POST['fcm_service_json'] ?? ''));
        if (strpos($sj, '{ saved') !== 0) {
            if ($sj === '') {
                $new['fcm_service_json'] = '';
            } else {
                $j = json_decode($sj, true);
                if (is_array($j) && !empty($j['private_key']) && !empty($j['client_email'])) {
                    $new['fcm_service_json'] = $sj;
                    if ($new['fcm_project_id'] === '' && !empty($j['project_id'])) $new['fcm_project_id'] = $j['project_id'];
                    delete_transient('volo_push_oauth');
                } else {
                    echo '<div class="notice notice-error"><p>Firebase JSON is not valid — kept the old one.</p></div>';
                }
            }
        }
        update_option('volo_settings', $new);
        $s = volo_settings();
        echo '<div class="notice notice-success"><p>Saved.</p></div>';
    }
    $f = function ($k, $label, $help = '', $type = 'text', $ph = '') use ($s) {
        echo '<tr><th>' . esc_html($label) . '</th><td><input type="' . $type . '" name="' . $k . '" value="' . esc_attr($s[$k]) . '" class="regular-text" placeholder="' . esc_attr($ph) . '" autocomplete="off">';
        if ($help) echo '<p class="description">' . $help . '</p>';
        echo '</td></tr>';
    };
    $users = (int) $GLOBALS['wpdb']->get_var('SELECT COUNT(*) FROM ' . volo_t('users'));
    ?>
    <div class="wrap"><h1>Volo Chat — Settings</h1>
    <p><?php echo $users; ?> users · API: <code><?php echo esc_html(rest_url('volo/v1/config')); ?></code></p>
    <form method="post"><?php wp_nonce_field('volo_admin'); ?>
    <h2>Phone sign-in (SMS code) — Twilio Verify</h2>
    <p class="description">Twilio console → Verify → Services → create a service. Copy its Service SID (VA…). Account SID (AC…) and Auth Token are on the console home page. Enable your users' countries in Verify → Settings → Geo permissions.</p>
    <table class="form-table">
    <?php
    $f('twilio_sid', 'Account SID', '', 'text', 'AC...');
    $f('twilio_token', 'Auth Token', '', 'password');
    $f('twilio_verify_sid', 'Verify Service SID', '', 'text', 'VA...');
    $f('test_code', 'Test code (optional)', '⚠️ For testing only: when set, this code signs in ANY number without an SMS. Leave empty in real use.', 'text', 'e.g. 246810');
    ?>
    <tr><th>Email verification</th><td><label><input type="checkbox" name="require_email" value="1" <?php checked($s['require_email']); ?>> Ask new users to verify an email address</label>
    <p class="description">Uses this site's email. If codes don't arrive, install "WP Mail SMTP".</p></td></tr>
    <?php $f('mail_from_name', 'Email sender name'); ?>
    </table>
    <h2>Calls (WebRTC)</h2><table class="form-table">
    <?php
    $f('stun_url', 'STUN URL(s)', 'Comma-separated.');
    $f('turn_url', 'TURN URL(s)', 'Needed on mobile data. e.g. metered.ca: turn:global.relay.metered.ca:80, turn:global.relay.metered.ca:443, turns:global.relay.metered.ca:443?transport=tcp');
    $f('turn_username', 'TURN username');
    $f('turn_credential', 'TURN credential', '', 'password');
    ?>
    </table>
    <h2>Push notifications (Firebase) — optional</h2><table class="form-table">
    <?php
    $f('fcm_api_key', 'Web API key'); $f('fcm_project_id', 'Project ID'); $f('fcm_sender_id', 'Sender ID');
    $f('fcm_android_app_id', 'Android App ID'); $f('fcm_ios_app_id', 'iOS App ID');
    ?>
    <tr><th>Service account JSON</th><td><textarea name="fcm_service_json" rows="4" class="large-text code"><?php echo esc_textarea($s['fcm_service_json'] !== '' ? '{ saved — paste again to replace }' : ''); ?></textarea></td></tr>
    </table>
    <p><button class="button button-primary" name="volo_save" value="1">Save settings</button></p></form></div>
    <?php
}

function volo_admin_users() {
    global $wpdb;
    if (!current_user_can('manage_options')) return;
    if (isset($_POST['volo_uid']) && check_admin_referer('volo_users')) {
        $uid = (int) $_POST['volo_uid'];
        if (isset($_POST['block'])) $wpdb->update(volo_t('users'), ['blocked' => 1, 'tokens' => '[]'], ['id' => $uid]);
        if (isset($_POST['unblock'])) $wpdb->update(volo_t('users'), ['blocked' => 0], ['id' => $uid]);
        echo '<div class="notice notice-success"><p>Updated.</p></div>';
    }
    $q = sanitize_text_field(wp_unslash($_GET['s'] ?? ''));
    $where = $q !== '' ? $wpdb->prepare(' WHERE phone LIKE %s OR name LIKE %s OR email LIKE %s', '%' . $wpdb->esc_like($q) . '%', '%' . $wpdb->esc_like($q) . '%', '%' . $wpdb->esc_like($q) . '%') : '';
    $rows = $wpdb->get_results('SELECT * FROM ' . volo_t('users') . $where . ' ORDER BY id DESC LIMIT 200', ARRAY_A);
    echo '<div class="wrap"><h1>Volo Chat Users</h1><form><input type="hidden" name="page" value="volo-chat-users"><input name="s" value="' . esc_attr($q) . '" placeholder="Phone, name or email"> <button class="button">Search</button></form>';
    echo '<table class="widefat striped" style="margin-top:12px"><thead><tr><th>ID</th><th>Name</th><th>Phone</th><th>Email</th><th>Last seen</th><th>Joined</th><th></th></tr></thead><tbody>';
    foreach ($rows as $u) {
        echo '<tr><td>' . (int) $u['id'] . '</td><td>' . esc_html($u['name']) . ($u['username'] ? ' <small>@' . esc_html($u['username']) . '</small>' : '') . '</td><td>' . esc_html($u['phone']) . '</td><td>' . esc_html((string) $u['email']) . ($u['email_verified'] ? ' ✅' : '') . '</td>';
        echo '<td>' . ($u['last_seen'] ? esc_html(human_time_diff((int) $u['last_seen']) . ' ago') : '—') . '</td><td>' . esc_html(date_i18n('Y-m-d', (int) $u['created'])) . '</td><td>';
        echo '<form method="post" style="display:inline">'; wp_nonce_field('volo_users');
        echo '<input type="hidden" name="volo_uid" value="' . (int) $u['id'] . '">' . ($u['blocked'] ? '<button class="button" name="unblock">Unblock</button>' : '<button class="button" name="block">Block</button>') . '</form></td></tr>';
    }
    echo '</tbody></table></div>';
}

// ================================================================ clean-up

add_action('init', function () {
    if (get_transient('volo_gc')) return;
    set_transient('volo_gc', 1, 6 * HOUR_IN_SECONDS);
    global $wpdb;
    $old = volo_now() - 2 * VOLO_STATUS_TTL;
    $wpdb->query($wpdb->prepare('DELETE v FROM ' . volo_t('status_views') . ' v JOIN ' . volo_t('statuses') . ' s ON s.id = v.status_id WHERE s.created < %d', $old));
    $wpdb->query($wpdb->prepare('DELETE FROM ' . volo_t('statuses') . ' WHERE created < %d', $old));
    $wpdb->query($wpdb->prepare('DELETE FROM ' . volo_t('calls') . ' WHERE created < %d', volo_now() - 120 * DAY_IN_SECONDS));
});
