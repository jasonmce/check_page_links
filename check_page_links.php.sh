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
$failure_codes    = array('308', '404');
 
$domDoc = new DOMDocument;
$domDoc->preserveWhiteSpace = false;

/**
 * Errors are suppressed so DOMDocument does not whine about XHTML.
 * If page fails to load return CRITICAL.
 */
if(!@$domDoc->loadHTMLFile($url)) {
 return $STATE_CRITICAL;
}

$links = $domDoc->getElementsByTagName('a');
$xpath = new DOMXpath($domDoc);
$NOT_pagelinks = $xpath->query('//a|//area');

// If page fails to load return UNKNOWN.
if (!count($links)) {
  return $STATE_UNKNOWN;
}

foreach($links as $link) {
  foreach($link->attributes as $attribute_name=>$attribute_value) {
    if('href' == $attribute_name) {
      // Test the link.
      $ch = curl_init($attribute_value->value);
      curl_setopt($ch, CURLOPT_NOBODY, true);
      curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
      curl_exec($ch);
      $response_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      $response_url   = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
      curl_close($ch);

      // Check the response.
      if(in_array($response_code, $failure_codes)) {
        $broken_links[]     = array('link'=>$attribute_value->value);
      } elseif ($response_url != $attribute_value->value) {
        $redirected_links[] = array('link'=>$attribute_value->value, 'redirect'=>$response_url);
      } else {
        $valid_links[]    = array('link'=>$attribute_value->value);
      }
    }
  }
}

// Output results as text.
// @todo Convert this to printf for performance?
print 'Valid Links ' . count($valid_links) . ": ";
print 'Broken Links ' . count($broken_links) . ": ";
print 'Redirected Links ' . count($redirected_links) . ": ";
print 'Duration ' . floor((microtime(true) - $start_time) * 100) / 100 . 's: ';

// If there is at least one good link and no bad links we are happy.
if (count($valid_links) && !count($broken_links)) {
  print "result is OK\n";
  return $STATE_OK;
}
// If there were at least good links, return a warning
if (count($valid_links)) {
  print "result is WARNING\n";
  return $STATE_WARNING;
}

print "result is CRITICAL\n";
// Otherwise we've only got broken links.
return $STATE_CRITICAL;
