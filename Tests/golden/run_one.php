<?php
// Runs the upstream PHP workflow for one query (argv[1], optional action argv[2]) and prints Alfred JSON.
chdir(dirname(__DIR__, 2));
$query = $argv[1] ?? '';
$action = $argv[2] ?? '';
require dirname(__DIR__, 2) . '/process.php';
