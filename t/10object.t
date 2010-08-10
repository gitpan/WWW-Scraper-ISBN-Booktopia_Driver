#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More tests => 40;
use WWW::Scraper::ISBN;

###########################################################

my $CHECK_DOMAIN = 'www.google.com';

my $scraper = WWW::Scraper::ISBN->new();
isa_ok($scraper,'WWW::Scraper::ISBN');

SKIP: {
	skip "Can't see a network connection", 39   if(pingtest($CHECK_DOMAIN));

	$scraper->drivers("Booktopia");

    # this ISBN doesn't exist
	my $isbn = "1234567890";
    my $record;
    eval { $record = $scraper->search($isbn); };
    if($@) {
        like($@,qr/Invalid ISBN specified/);
    }
    elsif($record->found) {
        ok(0,'Unexpectedly found a non-existent book');
    } else {
		like($record->error,qr/Failed to find that book on Booktopia website|website appears to be unavailable/);
    }

	$isbn = "0099547937";
	$record = $scraper->search($isbn);
    my $error  = $record->error || '';

    SKIP: {
        skip "Website unavailable", 19   if($error =~ /website appears to be unavailable/);

        unless($record->found) {
            diag($record->error);
        } else {
            is($record->found,1);
            is($record->found_in,'Booktopia');

            my $book = $record->book;
            is($book->{'isbn'},         '9780099547938'         ,'.. isbn found');
            is($book->{'isbn10'},       '0099547937'            ,'.. isbn10 found');
            is($book->{'isbn13'},       '9780099547938'         ,'.. isbn13 found');
            is($book->{'ean13'},        '9780099547938'         ,'.. ean13 found');
            is($book->{'title'},        'Ford County'           ,'.. title found');
            is($book->{'author'},       'John Grisham'          ,'.. author found');
            like($book->{'book_link'},  qr|http://www.booktopia.com.au/search.ep?cID=&submit.x=44&submit.y=7&submit=search&keywords=0099547937|);
            is($book->{'image_link'},   'http://tncdn.net/1/978/009/9547938.jpg');
            is($book->{'thumb_link'},   'http://tncdn.net/1/978/009/9547938.jpg');
            like($book->{'description'},qr|John Grisham takes you into the heart of America's Deep South|);
            is($book->{'publisher'},    'Cornerstone'           ,'.. publisher found');
            is($book->{'pubdate'},      '2010'                  ,'.. pubdate found');
            is($book->{'binding'},      'Paperback'             ,'.. binding found');
            is($book->{'pages'},        '352'                   ,'.. pages found');
            is($book->{'width'},        '111'                   ,'.. width found');
            is($book->{'height'},       '178'                   ,'.. height found');
            is($book->{'weight'},       undef                   ,'.. weight found');
        }
    }

	$isbn   = "9780007203055";
	$record = $scraper->search($isbn);
    $error  = $record->error || '';

    SKIP: {
        skip "Website unavailable", 19   if($error =~ /website appears to be unavailable/);

        unless($record->found) {
            diag($record->error);
        } else {
            is($record->found,1);
            is($record->found_in,'Booktopia');

            my $book = $record->book;
            is($book->{'isbn'},         '9780007203055'         ,'.. isbn found');
            is($book->{'isbn10'},       '0007203055'            ,'.. isbn10 found');
            is($book->{'isbn13'},       '9780007203055'         ,'.. isbn13 found');
            is($book->{'ean13'},        '9780007203055'         ,'.. ean13 found');
            like($book->{'author'},     qr/Simon Ball/          ,'.. author found');
            is($book->{'title'},        q|The Bitter Sea : The Brutal World War II Fight for the Mediterranean| ,'.. title found');
            like($book->{'book_link'},  qr|http://www.booktopia.com.au/the-bitter-sea-the-brutal-world-war-ii-fight-for-the-mediterranean/prod9780007203055.html|);
            is($book->{'image_link'},   'http://covers.booktopia.com.au/978000/720/9780007203055.jpg');
            is($book->{'thumb_link'},   'http://covers.booktopia.com.au/978000/720/9780007203055.jpg');
            like($book->{'description'},qr|The Mediterranean was indeed|);
            is($book->{'publisher'},    'HarperCollins Publishers Limited'  ,'.. publisher found');
            is($book->{'pubdate'},      '22nd June 2010'        ,'.. pubdate found');
            is($book->{'binding'},      'Paperback'             ,'.. binding found');
            is($book->{'pages'},        undef                   ,'.. pages found');
            is($book->{'width'},        133                     ,'.. width found');
            is($book->{'height'},       200                     ,'.. height found');
            is($book->{'weight'},       318                     ,'.. weight found');

            #use Data::Dumper;
            #diag("book=[".Dumper($book)."]");
        }
    }
    
    $isbn   = "9780718155896";
	$record = $scraper->search($isbn);
    $error  = $record->error || '';

    SKIP: {
        skip "Website unavailable", 19   if($error =~ /website appears to be unavailable/);

        unless($record->found) {
            diag($record->error);
        } else {
            is($record->found,1);
            is($record->found_in,'Booktopia');

            my $book = $record->book;
            is($book->{'isbn'},         '9780718155896'         ,'.. isbn found');
            is($book->{'isbn10'},       '0718155890'            ,'.. isbn10 found');
            is($book->{'isbn13'},       '9780718155896'         ,'.. isbn13 found');
            is($book->{'ean13'},        '9780718155896'         ,'.. ean13 found');
            is($book->{'author'},       q|Clive Cussler, Justin Scott|          ,'.. author found');
            is($book->{'title'},        q|The Spy : An Isaac Bell Adventure|    ,'.. title found');
            like($book->{'book_link'},  qr|http://www.booktopia.com.au/the-spy-an-isaac-bell-adventure/prod9780718155896.html|);
            is($book->{'image_link'},   'http://covers.booktopia.com.au/978071/815/9780718155896.jpg');
            is($book->{'thumb_link'},   'http://covers.booktopia.com.au/978071/815/9780718155896.jpg');
            like($book->{'description'},qr|international tensions are mounting as the world plunges towards war|);
            is($book->{'publisher'},    'Penguin Books, Limited','.. publisher found');
            is($book->{'pubdate'},      '31st May 2010'         ,'.. pubdate found');
            is($book->{'binding'},      'Paperback'             ,'.. binding found');
            is($book->{'pages'},        undef                   ,'.. pages found');
            is($book->{'width'},        152                     ,'.. width found');
            is($book->{'height'},       230                     ,'.. height found');
            is($book->{'weight'},       undef                   ,'.. weight found');

            #use Data::Dumper;
            #diag("book=[".Dumper($book)."]");
        }
    }
}

###########################################################

# crude, but it'll hopefully do ;)
sub pingtest {
    my $domain = shift or return 0;
    system("ping -q -c 1 $domain >/dev/null 2>&1");
    my $retcode = $? >> 8;
    # ping returns 1 if unable to connect
    return $retcode;
}
