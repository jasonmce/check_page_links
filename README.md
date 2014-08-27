check_page_links
================

Nagios plugin to check a page for broken links.  Simply takes a domain name, attaches http:// to it and checks all the <a> and <area> elements it can find with an 'href' attribute.  Later it should be expanded to check imgs and areas as well.

Remember that the plugin has to be 755 and owned by nagios:nagios to run!

For ease of use we're considering a 405 a valid link.  Its just one where the server does not like the way we are asking.