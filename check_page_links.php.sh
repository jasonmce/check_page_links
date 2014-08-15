#!/usr/bin/php
<?php
// @todo Add a timeout parameter.
$start_time = microtime(true);

// @todo Load these from an include file.
$STATE_OK = 0;
$STATE_WARNING = 1;
$STATE_CRITICAL = 2;
$STATE_UNKNOWN = 3;
$STATE_DEPENDENT = 4;

if (empty($argv)) {
  print "Requires an URL to check.\n";
  return $STATE_UNKNOWN;
}

// @todo Should be an an argument for http vs https.
$url = "http://" . $argv[1];

// Doing these as arrays in case I want to recurse later.
$valid_links      = array();
$redirected_links = array();
$broken_links     = array();

$domDoc = new DOMDocument;
$domDoc->preserveWhiteSpace = false;

/**
 * Errors are suppressed so DOMDocument does not whine about XHTML.
 * If page fails to load return CRITICAL.
 */
if(!@$domDoc->loadHTMLFile($url)) {
 exit($STATE_CRITICAL);
}

$xpath = new DOMXpath($domDoc);
$links = $xpath->query('//a | //area');

// If page lacks any links return UNKNOWN.
if (!count($links)) {
  exit($STATE_UNKNOWN);
}

foreach($links as $link) {
  foreach($link->attributes as $attribute_name=>$attribute_value) {
    if('href' == $attribute_name &&
        strncmp('mailto:', $attribute_value->value, 7)) {
      // To test the link we may need to prepend http:// and the current path.
      $preface = (!strncmp('http', $attribute_value->value, 4)) ? '' : "$url/";
      $ch = curl_init($preface . $attribute_value->value);
      curl_setopt($ch, CURLOPT_NOBODY, true);
      curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
      curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
      curl_exec($ch);
      $response_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      // Could be refusal to respond to CURLOPT_NOBODY, like amazon.com does.
      if (405 == $response_code) {
        curl_setopt($ch, CURLOPT_BUFFERSIZE, 64);
        curl_setopt($ch, CURLOPT_NOPROGRESS, false);
        curl_setopt($ch, CURLOPT_PROGRESSFUNCTION, function(
            $clientp, $dltotal, $dlnow, $ultotal, $ulnow
        ){
            // Returning non-0 breaks the connection.
            return $dlnow;
        });
        curl_setopt($ch, CURLOPT_NOBODY, false);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_exec($ch);
        $response_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      }
      $response_url  = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
      curl_close($ch);

      // Check response using www.w3.org/Protocols/rfc2616/rfc2616-sec10.html.
      switch(intval($response_code / 100)) {
        case 1  :
        case 2  : $valid_links[] = $attribute_value->value;
                  break;
        case 3  : $redirected_links[] = $response_url;
                  break;
        default : $broken_links[] = $attribute_value->value;

        // This would be a good place for a debug flag.
        // echo $response_code . " - " .$attribute_value->value . "\n";
      }
    }
  }
}

// Output results as text.
// @todo Convert this to printf for performance?
print 'Valid Links ' . count($valid_links) . ": ";
print 'Redirected Links ' . count($redirected_links) . ": ";
print 'Broken Links ' . count($broken_links) . ": ";

// If there is at least one good link and no bad links we are happy.
if (count($valid_links) && !count($broken_links)) {
  print "result is OK\n";
  exit($STATE_OK);
}
// If there were at least good links, return a warning
if (count($valid_links)) {
  print "result is WARNING\n";
  exit($STATE_WARNING);
}

print "result is CRITICAL\n";
// Otherwise we've only got broken links.
exit($STATE_CRITICAL);
