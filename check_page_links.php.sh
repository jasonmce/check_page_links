#!/usr/bin/php
<?php
/**
 * @file
 * Nagios scriplet check_page_links.php.sh to check links.
 */

// @todo Add a timeout parameter.
$start_time = microtime(TRUE);

// @todo Load these from an include file.
$STATE_OK = 0;
$STATE_WARNING = 1;
$STATE_CRITICAL = 2;
$STATE_UNKNOWN = 3;
$STATE_DEPENDENT = 4;


$options = @getopt("H:t:v:");
if (empty($options['H'])) {
  print "Requires an URL to check.\n";
  print "options are -H hostname -t THRESHOLD -v VERBOSE_OUTPUT\n";
  return $STATE_UNKNOWN;
}

// Argument t for threshold.
$threshold = (isset($options['t']) ? intval($options['t']) : 0);

// @todo Should be an an argument for http vs https.
$url = "http://" . $options['H'];

// Doing these as arrays in case I want to recurse later.
$valid_links      = array();
$redirected_links = array();
$broken_links     = array();

$domDoc = new DOMDocument;
$domDoc->preserveWhiteSpace = FALSE;

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

// Returning non-0 breaks the connection.
function progress_watcher($clientp, $dltotal, $dlnow, $ultotal, $ulnow) {
  return $dlnow;
}

foreach($links as $link) {
  foreach ($link->attributes as $attribute_name => $attribute_value) {
    if ('href' == $attribute_name &&
        strncmp('mailto:', $attribute_value->value, 7) &&
        strncmp('tel:', $attribute_value->value, 4)) {
      // To test the link we may need to prepend http:// and the current path.
      $preface = (!strncmp('http', $attribute_value->value, 4)) ? '' : "$url/";
      $ch = curl_init($preface . $attribute_value->value);
      curl_setopt($ch, CURLOPT_NOBODY, TRUE);
      curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
      curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, TRUE);

      curl_exec($ch);
      $response_url  = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
      $response_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
      curl_close($ch);

      // Check response using www.w3.org/Protocols/rfc2616/rfc2616-sec10.html.
      // 405 is just a snobbish 200 in my book.
      if ($response_code < 299  || $response_code == 405) {
        $valid_links[] = $attribute_value->value;
      }
      elseif ($response_code < 399) {
        $redirected_links[] = $response_url;
      }
      else {
        $broken_links[] = $attribute_value->value;

        // This would be a good place for a debug flag.
        // echo $response_code . " - " .$attribute_value->value . "\n";
      }
    }
  }
}

// Output results as text.
// @todo Convert this to printf for performance?
if (empty($options['v'])) {
  print 'Valid Links ' . count($valid_links) . ": ";
  print 'Redirected Links ' . count($redirected_links) . ": ";
  print 'Broken Links ' . count($broken_links) . ": ";
}
else {
  print "Valid links:\n" . print_r($valid_links, 1);
  print "\n\nRedirected links:\n" . print_r($redirected_links, 1);
  print "\n\nBroken links:\n" . print_r($broken_links, 1);
}

// If bad links are below the threshold, we are content.
if (count($broken_links) <= $threshold) {
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
