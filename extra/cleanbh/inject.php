$rflClass = new \ReflectionClass(__CLASS__);
$docblock = $rflClass->getMethod(__FUNCTION__)->getDocComment();

$matches = [];
if (preg_match_all('/@((?:Given|given|When|when|Then|then).+)/', $docblock, $matches) > 0) {
    foreach ($matches[1] as $step) {
        file_put_contents("LOGGING_FILE_PATH", $step . "\n", FILE_APPEND);
    }
}