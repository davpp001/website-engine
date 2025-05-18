<?php
// Nur POST-Anfragen erlauben
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit;
}

// JSON-Body parsen
$input = json_decode(file_get_contents('php://input'), true);

// Subdomain validieren
if (empty($input['subdomain']) || !preg_match('/^[a-z0-9-]+$/', $input['subdomain'])) {
    http_response_code(400);
    echo "Invalid subdomain";
    exit;
}

$sub = $input['subdomain'];

// Hintergrund-Job starten
$cmd = sprintf(
    'nohup sudo /bin/bash /usr/local/bin/setup_wp_webhook.sh %s > /var/log/setup_wp.log 2>&1 &',
    escapeshellarg($sub)
);
exec($cmd, $out, $rc);

// Antwort zurückgeben
if ($rc === 0) {
    http_response_code(202);
    echo "Triggered: $sub";
} else {
    http_response_code(500);
    echo "Trigger failed";
}