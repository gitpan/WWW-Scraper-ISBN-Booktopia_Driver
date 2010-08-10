package WWW::Scraper::ISBN::Booktopia_Driver;

use strict;
use warnings;

use vars qw($VERSION @ISA);
$VERSION = '0.01';

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

Creates a query string, then passes the appropriate form fields to the Booktopia
server.

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

The book_link and image_link refer back to the Booktopia website.

=back

=cut

sub search {
	my $self = shift;
	my $isbn = shift;
	$self->found(0);
	$self->book(undef);

	my $mech = WWW::Mechanize->new();
    $mech->agent_alias( 'Linux Mozilla' );

    eval { $mech->get( SEARCH . $isbn ) };
    return $self->handler("Booktopia website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

    my $content = $mech->content;
    my ($link) = $content =~ m!"($BAU_URL2$isbn$BAU_URL3)"!s;
	return $self->handler("Failed to find that book on Booktopia website.")
	    unless($link);

#print STDERR "\n# content1=[\n$content\n]\n";
#print STDERR "\n# link1=[$BAU_URL2$isbn$BAU_URL3]\n";
#print STDERR "\n# link2=[$BAU_URL1$link]\n";

    eval { $mech->get( $BAU_URL1 . $link ) };
    return $self->handler("Booktopia website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

	# The Book page
    my $html = $mech->content();

	return $self->handler("Failed to find that book on Booktopia website. [$isbn]")
		if($html =~ m!Sorry, we couldn't find any matches for!si);
    
#print STDERR "\n# content2=[\n$html\n]\n";

    my $data;
    ($data->{publisher})                = $html =~ m!<span class="bold">\s*Publisher:\s*</span>\s*([^<]+)!i;
    ($data->{pubdate})                  = $html =~ m!<span class="bold">\s*Published:\s*</span>\s*([^<]+)!i;

    $data->{publisher} =~ s!<[^>]+>!!g  if($data->{publisher});
    $data->{pubdate} =~ s!\s+! !g       if($data->{pubdate});


    ($data->{image})                    = $html =~ m!(http://covers.booktopia.com.au/\d+/\d+/\d+.jpg)!i;
    ($data->{thumb})                    = $html =~ m!(http://covers.booktopia.com.au/\d+/\d+/\d+.jpg)!i;
    ($data->{isbn13})                   = $html =~ m!<b>\s*ISBN:\s*</b>\s*(\d+)!i;
    ($data->{isbn10})                   = $html =~ m!<b>\s*ISBN-10:\s*</b>\s*(\d+)!i;
    ($data->{author})                   = $html =~ m!<span class="bold">By:\s*</span>((?:<a href="/search.ep\?author=[^"]+">[^<]+</a>[,\s]*)+)<br/>!i;
    ($data->{title})                    = $html =~ m!<meta property="og:title" content="([^"]+)"!i;
    ($data->{title})                    = $html =~ m!<a href="[^"]+" class="largeLink">([^<]+)</a><br/><br/>!i  unless($data->{title});
    ($data->{description})              = $html =~ m!<div id="product-description">(.*?)</div>\s*<div id="(?:details|extract)"!s;
    ($data->{description})              = $html =~ m!<h4>Description:</h4>([^<]+)!  unless($data->{description});
    ($data->{binding})                  = $html =~ m!<b>Format:\s*</b>([^<]+)!s;
    ($data->{pages})                    = $html =~ m!<b>\s*Number Of Pages:\s*</b>\s*([\d.]+)!s;
    ($data->{weight})                   = $html =~ m!<span class="bold">\s*Weight \(kg\):\s*</span>\s*([\d.]+)!s;
    ($data->{height},$data->{width})    = $html =~ m!<span class="bold">\s*Dimensions \(cm\):\s*</span>([\d.]+)&nbsp;x&nbsp;([\d.]+)!s;

    $data->{weight} = int($data->{weight} * 1000)   if($data->{weight});
    $data->{height} = int($data->{height} * 10)     if($data->{height});
    $data->{width}  = int($data->{width}  * 10)     if($data->{width});

    $data->{author} =~ s!<[^>]+>!!g;
    $data->{description} =~ s!<div.*?</div>!!s;
    $data->{description} =~ s!<a .*!!s;
    $data->{description} =~ s!</?b>!!g;
    $data->{description} =~ s!<br\s*/>!\n!g;
    $data->{description} =~ s! +$!!gm;
    $data->{description} =~ s!\n\n!\n!gs;

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
		'height'		=> $data->{height}
	};

#use Data::Dumper;
#print STDERR "\n# book=".Dumper($bk);

    $self->book($bk);
	$self->found(1);
	return $self->book;
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

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  Miss Barbell Productions, <http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2010 Barbie for Miss Barbell Productions

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
