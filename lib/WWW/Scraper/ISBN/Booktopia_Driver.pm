package WWW::Scraper::ISBN::Booktopia_Driver;

use strict;
use warnings;

use vars qw($VERSION @ISA);
$VERSION = '0.16';

#--------------------------------------------------------------------------

=head1 NAME

WWW::Scraper::ISBN::Booktopia_Driver - Search driver for Booktopia online book catalog.

=head1 SYNOPSIS

See parent class documentation (L<WWW::Scraper::ISBN::Driver>)

=head1 DESCRIPTION

Searches for book information from Booktopia online book catalog

=cut

#--------------------------------------------------------------------------

###########################################################################
# Inheritence

use base qw(WWW::Scraper::ISBN::Driver);

###########################################################################
# Modules

use WWW::Mechanize;

###########################################################################
# Constants

use constant	SEARCH	=> 'http://www.booktopia.com.au/search.ep?cID=&submit.x=44&submit.y=7&submit=search&keywords=';
my ($BAU_URL1,$BAU_URL2,$BAU_URL3) = ('http://www.booktopia.com.au','/[^/]+/prod','.html');

#--------------------------------------------------------------------------

###########################################################################
# Public Interface

=head1 METHODS

=over 4

=item C<search()>

Creates a query string, then passes the appropriate form fields to the 
Booktopia server.

The returned page should be the correct catalog page for that ISBN. If not the
function returns zero and allows the next driver in the chain to have a go. If
a valid page is returned, the following fields are returned via the book hash:

  isbn          (now returns isbn13)
  isbn10        
  isbn13
  ean13         (industry name)
  author
  title
  book_link
  image_link
  description
  pubdate
  publisher
  binding       (if known)
  pages         (if known)
  weight        (if known) (in grammes)
  width         (if known) (in millimetres)
  height        (if known) (in millimetres)
  depth         (if known) (in millimetres)

The book_link and image_link refer back to the Booktopia website.

=cut

sub search {
	my $self = shift;
	my $isbn = shift;
	$self->found(0);
	$self->book(undef);

    # validate and convert into EAN13 format
    my $ean = $self->convert_to_ean13($isbn);
    return $self->handler("Invalid ISBN specified [$isbn]")   
        if(!$ean || (length $isbn == 13 && $isbn ne $ean)
                 || (length $isbn == 10 && $isbn ne $self->convert_to_isbn10($ean)));

#print STDERR "\n# isbn=[$isbn] => ean=[$ean]\n";
    $isbn = $ean;

    my $mech = WWW::Mechanize->new();
    $mech->agent_alias( 'Linux Mozilla' );

#print STDERR "\n# url=[".(SEARCH . $isbn)."]\n";

    eval { $mech->get( SEARCH . $isbn ) };
    return $self->handler("Booktopia website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

    my $pattern = $isbn;
    if(length $isbn == 10) {
        $pattern = '978' . $isbn;
        $pattern =~ s/.$/./;
    }

	# The Book page
    my $html = $mech->content();

	return $self->handler("Failed to find that book on Booktopia website. [$isbn]")
		if($html =~ m!Sorry, we couldn't find any matches for!si);
    
#print STDERR "\n# html=[\n$html\n]\n";

    my $data;
    ($data->{publisher})                = $html =~ m!<span class="label">\s*Publisher:\s*</span>\s*([^<]+)!si;
    ($data->{pubdate})                  = $html =~ m!<span class="label">\s*Published:\s*</span>\s*([^<]+)!si;

    $data->{publisher} =~ s!<[^>]+>!!g  if($data->{publisher});
    $data->{pubdate} =~ s!\s+! !g       if($data->{pubdate});

    ($data->{image})                    = $html =~ m!(http://covers.booktopia.com.au/big/\d+/[-\w]+\.jpg)!si;
    ($data->{thumb})                    = $html =~ m!(http://covers.booktopia.com.au/\d+/\d+/[-\w]+\.jpg)!si;
    ($data->{isbn13})                   = $html =~ m!<b>\s*ISBN:\s*</b>\s*(\d+)!si;
    ($data->{isbn10})                   = $html =~ m!<b>\s*ISBN-10:\s*</b>\s*(\d+)!si;
    ($data->{author})                   = $html =~ m!<div id="contributors">\s*(?:By|Author):\s*(.*?)</div>!si;
    ($data->{title})                    = $html =~ m!<meta property="og:title" content="([^"]+)"!si;
    ($data->{title})                    = $html =~ m!<a href="[^"]+" class="largeLink">([^<]+)</a><br/><br/>!si  unless($data->{title});
    ($data->{description})              = $html =~ m!<div id="description">(.*?)</div>!si;
    ($data->{binding})                  = $html =~ m!<span class="label">\s*Format:\s*</span>\s*([^<]+)!si;
    ($data->{pages})                    = $html =~ m!<b>\s*Number Of Pages:\s*</b>\s*([\d.]+)!si;
    ($data->{weight})                   = $html =~ m!<span class="label">\s*Weight \(kg\):\s*</span>\s*([\d.]+)!si;
    ($data->{height},$data->{width},$data->{depth})
                                        = $html =~ m!<span class="label">\s*Dimensions \(cm\):\s*</span>([\d.]+)\s*&nbsp;x&nbsp;\s*([\d.]+)\s*&nbsp;x&nbsp;\s*([\d.]+)!si;

    # despite it saying Kg (kilogrammes) the weight seems to vary between widely!
    if($data->{weight}) {
        if(   $data->{weight} < 1)      {$data->{weight} = int($data->{weight} * 1000)} 
        elsif($data->{weight} < 100)    {$data->{weight} = int($data->{weight} * 10)}
        elsif($data->{weight} < 1000)   {$data->{weight} = int($data->{weight})}
        else                            {$data->{weight} = int($data->{weight})}
    }
    
    $data->{height} = int($data->{height} * 10)     if($data->{height});
    $data->{width}  = int($data->{width}  * 10)     if($data->{width});
    $data->{depth}  = int($data->{depth}  * 10)     if($data->{depth});

    if($data->{author}) {
        $data->{author} =~ s!<br\s*/>!,!g;
        $data->{author} =~ s!<[^>]+>!!g;
        $data->{author} =~ s!\s*,\s*!, !g;
        $data->{author} =~ s!\s*,\s*$!!g;
    }

    if($data->{description}) {
        $data->{description} =~ s!Click on the Google Preview[^<]+!!s;
        $data->{description} =~ s!<br\s*/?>!\n!gi;
        $data->{description} =~ s!<[^>]+>!!g;
    }

#use Data::Dumper;
#print STDERR "\n# " . Dumper($data);

	return $self->handler("Could not extract data from Booktopia result page.")
		unless(defined $data);

	# trim top and tail
	foreach (keys %$data) { next unless(defined $data->{$_});$data->{$_} =~ s/^\s+//;$data->{$_} =~ s/\s+$//; }

	my $bk = {
		'ean13'		    => $data->{isbn13},
		'isbn13'		=> $data->{isbn13},
		'isbn10'		=> $data->{isbn10},
		'isbn'			=> $data->{isbn13},
		'author'		=> $data->{author},
		'title'			=> $data->{title},
		'book_link'		=> $mech->uri(),
		'image_link'	=> $data->{image},
		'thumb_link'	=> $data->{thumb},
		'description'	=> $data->{description},
		'pubdate'		=> $data->{pubdate},
		'publisher'		=> $data->{publisher},
		'binding'	    => $data->{binding},
		'pages'		    => $data->{pages},
		'weight'		=> $data->{weight},
		'width'		    => $data->{width},
		'height'		=> $data->{height},
		'depth'		    => $data->{depth},
        'html'          => $html
	};

#use Data::Dumper;
#print STDERR "\n# book=".Dumper($bk);

    $self->book($bk);
	$self->found(1);
	return $self->book;
}

=item C<convert_to_ean13()>

Given a 10/13 character ISBN, this function will return the correct 13 digit
ISBN, also known as EAN13.

=item C<convert_to_isbn10()>

Given a 10/13 character ISBN, this function will return the correct 10 digit 
ISBN.

=back

=cut

sub convert_to_ean13 {
	my $self = shift;
    my $isbn = shift;
    my $prefix;

    return  unless(length $isbn == 10 || length $isbn == 13);

    if(length $isbn == 13) {
        return  if($isbn !~ /^(978|979)(\d{10})$/);
        ($prefix,$isbn) = ($1,$2);
    } else {
        return  if($isbn !~ /^(\d{10}|\d{9}X)$/);
        $prefix = '978';
    }

    my $isbn13 = '978' . $isbn;
    chop($isbn13);
    my @isbn = split(//,$isbn13);
    my ($lsum,$hsum) = (0,0);
    while(@isbn) {
        $hsum += shift @isbn;
        $lsum += shift @isbn;
    }

    my $csum = ($lsum * 3) + $hsum;
    $csum %= 10;
    $csum = 10 - $csum  if($csum != 0);

    return $isbn13 . $csum;
}

sub convert_to_isbn10 {
	my $self = shift;
    my $ean  = shift;
    my ($isbn,$isbn10);

    return  unless(length $ean == 10 || length $ean == 13);

    if(length $ean == 13) {
        return  if($ean !~ /^(?:978|979)(\d{9})\d$/);
        ($isbn,$isbn10) = ($1,$1);
    } else {
        return  if($ean !~ /^(\d{9})[\dX]$/);
        ($isbn,$isbn10) = ($1,$1);
    }

	return  if($isbn < 0 or $isbn > 999999999);

	my ($csum, $pos, $digit) = (0, 0, 0);
    for ($pos = 9; $pos > 0; $pos--) {
        $digit = $isbn % 10;
        $isbn /= 10;             # Decimal shift ISBN for next time 
        $csum += ($pos * $digit);
    }
    $csum %= 11;
    $csum = 'X'   if ($csum == 10);
    return $isbn10 . $csum;
}

1;

__END__

=head1 REQUIRES

Requires the following modules be installed:

L<WWW::Scraper::ISBN::Driver>,
L<WWW::Mechanize>

=head1 SEE ALSO

L<WWW::Scraper::ISBN>,
L<WWW::Scraper::ISBN::Record>,
L<WWW::Scraper::ISBN::Driver>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Scraper-ISBN-Booktopia_Driver).
However, it would help greatly if you are able to pinpoint problems or even
supply a patch.

Fixes are dependent upon their severity and my availability. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  Miss Barbell Productions, <http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2010-2013 Barbie for Miss Barbell Productions

  This distribution is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
