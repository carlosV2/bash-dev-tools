<?php

$content = file_get_contents($argv[1]);
$inject = str_replace('LOGGING_FILE_PATH', str_replace('//', '/', $argv[3]), file_get_contents($argv[2]));

$content = preg_replace('/(public\sfunction\s[^{]+{)/', '${1}' . $inject, $content);

file_put_contents($argv[1], $content);