package Selenium::Screenshot;
$Selenium::Screenshot::VERSION = '0.03';
# ABSTRACT: Compare and contrast Webdriver screenshots in PNG format
use Moo;
use Image::Compare;
use Imager qw/:handy/;
use Imager::Color;
use Imager::Fountain;
use Carp qw/croak carp/;
use Cwd qw/abs_path/;
use MIME::Base64;
use Scalar::Util qw/blessed/;


has png => (
    is => 'rwp',
    lazy => 1,
    coerce => sub {
        my ($png_or_image) = @_;

        # We are prepared to handle an Imager object, or a base64
        # encoded png.
        if ( blessed( $png_or_image ) && $png_or_image) {
            return $png_or_image;
        }
        else {
            my $data = decode_base64($png_or_image);
            return Imager->new(data => $data);
        }
    },
    required => 1
);


has exclude => (
    is => 'ro',
    lazy => 1,
    default => sub { [ ] },
    coerce => sub {
        my ($exclude) = @_;

        foreach my $rect (@{ $exclude }) {
            croak 'Each exclude region must have size and location keys.'
              unless exists $rect->{size} && exists $rect->{location};
        }

        return $exclude;
    },
    predicate => 1
);


# TODO: add threshold tests
# TODO: provide reference images

has threshold => (
    is => 'ro',
    lazy => 1,
    coerce => sub {
        my ($threshold) = @_;

        my $scaling = 255 * sqrt(3) / 100;
        return $threshold * $scaling;
    },
    default => sub { 5 }
);


has folder => (
    is => 'rw',
    coerce => sub {
        my ($folder) = @_;
        $folder //= 'screenshots/';
        mkdir $folder unless -d $folder;

        return abs_path($folder) . '/';
    },
    default => sub { 'screenshots/' }
);


has metadata => (
    is => 'ro',
    lazy => 1,
    default => sub { {} },
    predicate => 'has_metadata'
);

has _cmp => (
    is => 'ro',
    lazy => 1,
    init_arg => undef,
    builder => sub {
        my ($self) = @_;
        my $cmp = Image::Compare->new;

        if ($self->has_exclude) {
            my $png = $self->_img_exclude($self->png);
            $self->_set_png($png);
        }

        $cmp->set_image1(
            img => $self->png,
            type => 'png'
        );

        return $cmp;
    }
);


sub compare {
    my ($self, $opponent) = @_;
    $self->_set_opponent($opponent);

    $self->_cmp->set_method(
        method => &Image::Compare::AVG_THRESHOLD,
        args   => {
            type  => &Image::Compare::AVG_THRESHOLD::MEAN,
            value => $self->threshold,
        }
    );

    return $self->_cmp->compare;
}


sub difference {
    my ($self, $opponent) = @_;
    $opponent = $self->_set_opponent($opponent);

    # We want to range from transparent (no difference) to fuschia at
    # 100% change.
    my $white = Imager::Color->new(255, 255, 255);
    my $fuschia = Imager::Color->new(240,  18, 190);
    my $scale = Imager::Fountain->simple(
        positions => [    0.0,      1.0 ],
        colors    => [ $white, $fuschia ]
    );

    $self->_cmp->set_method(
        method => &Image::Compare::IMAGE,
        args => $scale
    );

    # Do the actual pixel by pixel comparison. This can take a while.
    my $diff = $self->_cmp->compare;

    # Post processing to overlay the difference onto the
    # opponent. First, subtract a white box from our difference image;
    # to make everything white transparent instead.
    my $work = Imager->new(
        xsize    => $diff->getwidth,
        ysize    => $diff->getheight,
        channels => $diff->getchannels
    );
    $work->box(filled => 1, color => $white );
    $diff = $work->difference(other => $diff);

    # Place the transparent diff image on top of our opponent -
    # anything changed will show up on top of the opponent image in
    # varying degrees of pink.
    $opponent->compose(src => $diff);

    my $name = $self->_diff_filename;
    $opponent->write(file => $name);

    return $name;
}

sub _diff_filename {
    my ($self) = @_;

    # we'd like to suffix "diff" on to the filename to separate the
    # diff files from the normal files. But, since we're sorting the
    # keys of our metadata, we need to be a little clever about naming
    # the key of what we're passing to ->filename.
    my $suffix = 'suffix';
    if ($self->has_metadata) {
        my @keys = sort keys %{ $self->metadata };
        my $last_key = pop @keys;
        $suffix = 'z' . $last_key;
    }

    return $self->filename($suffix => 'diff');
}

sub _set_opponent {
    my ($self, $opponent) = @_;

    $opponent = $self->_extract_image($opponent);
    $opponent = $self->_img_exclude($opponent);
    $self->_cmp->set_image2( img => $opponent );

    return $opponent;
}


sub filename {
    my ($self, %overrides) = @_;

    my @filename_parts;
    if ($self->has_metadata or %overrides) {
        my $metadata = {
            %{ $self->metadata},
            %overrides
        };

        foreach (sort keys %{ $metadata }) {
            push @filename_parts, $self->_sanitize_string($metadata->{$_});
        }
    }
    else {
        push @filename_parts, time
    }

    my $filename = $self->folder . join('-', @filename_parts) . '.png';
    $filename =~ s/\-+/-/g;
    return $filename;
}


sub save {
    my ($self, %overrides) = @_;

    my $png = $self->png;
    my $filename =  $self->filename(%overrides);
    $png->write(file => $filename);

    return $filename;
}

sub _img_exclude {
    my ($self, $img, $exclude) = @_;
    $exclude //= $self->exclude;

    my $copy = $img->copy;

    foreach my $rect (@{ $exclude }) {
        my ($size, $loc) = ($rect->{size}, $rect->{location});

        # skip items that don't have the valid keys
        unless (exists $loc->{x}
                && exists $loc->{y}
                && exists $size->{width}
                && exists $size->{height}) {
            next;
        }

        my $top_left = {
            x => $loc->{x},
            y => $loc->{y}
        };

        my $bottom_right = {
            x => $loc->{x} + $size->{width},
            y => $loc->{y} + $size->{height}
        };

        $copy->box(
            xmin => $top_left->{x},
            ymin => $top_left->{y},
            xmax => $bottom_right->{x},
            ymax => $bottom_right->{y},
            filled => 1,
            color => 'black'
        );
    }

    return $copy;
}

sub _sanitize_string {
    my ($self, $dirty_string) = @_;

    $dirty_string =~ s/[^A-z0-9\.\-]/-/g;
    return $dirty_string;
}

sub _extract_image {
    my ($self, $file_or_image) = @_;

    my $err_msg = 'We were expecting one of: a filename, Imager object, or Selenium::Screenshot object';
    die $err_msg unless defined $file_or_image;

    if ( blessed( $file_or_image) ) {
        if ($file_or_image->isa('Selenium::Screenshot')) {
            return $file_or_image->png;
        }
        elsif ($file_or_image->isa('Imager')) {
            return $file_or_image;
        }
        else {
            croak $err_msg;
        }
    }
    else {
        return Imager->new(file => $file_or_image);
    }
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Selenium::Screenshot - Compare and contrast Webdriver screenshots in PNG format

=for markdown [![Build Status](https://travis-ci.org/gempesaw/Selenium-Screenshot.svg?branch=master)](https://travis-ci.org/gempesaw/Selenium-Screenshot)

=head1 VERSION

version 0.03

=head1 SYNOPSIS

    my $driver = Selenium::Remote::Driver->new;
    $driver->set_window_size(320, 480);
    $driver->get('http://www.google.com/404');

    my $white = Selenium::Screenshot->new(png => $driver->screenshot);

    # Alter the page by turning the background blue
    $driver->execute_script('document.getElementsByTagName("body")[0].style.backgroundColor = "blue"');

    # Take another screenshot
    my $blue = Selenium::Screenshot->new(png => $driver->screenshot);

    unless ($white->compare($blue)) {
        my $diff_file = $white->difference($blue);
        print 'The images differ; see ' . $diff_file . ' for details';
    }

=head1 DESCRIPTION

Selenium::Screenshot is a wrapper class for L<Image::Compare>. It
dumbly handles persisting your screenshots to disk and setting up the
parameters to L<Image::Compare> to allow you to extract difference
images between two states of your app. For example, you might be
interested in ensuring that your CSS refactor hasn't negatively
impacted other parts of your web app.

=head1 INSTALLATION

This module depends on L<Image::Compare> for comparison, and
L<Imager::File::PNG> for PNG support. The latter depends on
C<libpng-devel>; consult L<Image::Install>'s documentation and/or your
local googles on how to get the appropriate libraries installed on
your system. The following commands may be of aid on linux systems, or
they may not help at all:

    sudo apt-get install libpng-dev
    sudo yum install libpng-devel

For OS X, perhaps L<this
page|http://ethan.tira-thompson.com/Mac_OS_X_Ports.html> may help.

=head1 ATTRIBUTES

=head2 png

REQUIRED - A base64 encoded string representation of a PNG. For
example, the string that the Selenium Webdriver server returns when
you invoke the L<Selenium::Remote::Driver/screenshot> method. After
being passed to our constructor, this will be automatically
instantiated into an Imager object: that is, C<< $screenshot->png >>
will return an Imager object.

If you are so inclined, you may also pass an Imager object instead of
a base64 encoded PNG.

=head2 exclude

OPTIONAL - Handle dynamic parts of your website by specify areas of the
screenshot to black out before comparison. We're working on
simplifying this data structure as much as possible, but it's a bit
complicated to handle the output of the functions from
Selenium::Remote::WebElement. If you have WebElements already found
and instantiated, you can do:

    my $elem = $driver->find_element('div', 'css');
    Selenium::Screenshot->new(
        png => $driver->screenshot,
        exclude => [{
            size      => $elem->get_size,
            location  => $elem->get_element_location
        }]
    );

To construct the exclusions by hand, you can do:

    Selenium::Screenshot->new(
        png => $driver->screenshot,
        exclude => [{
            size     => { width => 10, height => 10 }
            location => { x => 5, y => 5 },
        }]
    );

This would black out a 10x10 box with its top left corner 5 pixels
from the top edge and 5 pixels from the left edge of the image.

You may pass more than one rectangle at a time.

Unfortunately, while we would like to accept CSS selectors, it feels a
bit wrong to have to obtain the element's size and location from this
module, which would make a binding dependency on
Selenium::Remote::WebElement's interface. Although this is more
cumbersome, it's a cleaner separation. In case you need help
generating your exclude data structure, the following map might help:

    my @elems = $d->find_elements('p', 'css');
    my @exclude = map {
        my $rect = {
            size => $_->get_size,
            location => $_->get_element_location
        };
        $rect
    } @elems;
    my $s = Selenium::Screenshot->new(
        png => $d->screenshot,
        exclude => [ @exclude ],
    );

=head2 threshold

OPTIONAL - set the threshold at which images should be considered the
same. The range is from 0 to 100; for comparison, these two images are
N percent different, and these two images are N percent different. The
default threshold is 5 out of 100.

=head2 folder

OPTIONAL - a string where you'd like to save the screenshots on your
local machine. It will be run through L<Cwd/abs_path> and we'll try to
save there. If you don't pass anything and you invoke L</save>, we'll
try to save in C<($pwd)/screenshots/>, wherever that may be.

=head2 metadata

OPTIONAL - provide a HASHREF of any additional data you'd like to use
in the filename. They'll be appended together in the filename of this
screenshot. Rudimentary sanitization is applied to the values of the
hashref, but it's not very clever and is probably easily subverted -
characters besides letters, numbers, dashes, and periods are
regex-substituted by '-' in the filename.

    my $screenshot = Selenium::Screenshot->new(
        png => $encoded,
        metadata => {
            url     => 'http://fake.url.com',
            build   => 'random-12347102.238402-build',
            browser => 'firefox'
        }
    );

=head1 METHODS

=head2 compare

C<compare> requires one argument: the filename, Imager object, or
Selenium::Screenshot of a PNG to compare against. It must be the exact
same size as the PNG you passed in to this instance of Screenshot. It
returns a boolean as to whether the images meet your L</threshold> for
similarity.

=head2 difference

C<difference> requires one argument: the filename of a PNG, an Imager
object, or a Selenium::Screenshot object instantiated from such a
PNG. Like L</compare>, the opponent image MUST be a PNG of the exact
same size as the PNG you passed into this instance of screenshot. Note
that for larger images, this method will take noticeably longer to
resolve.

This will return the filename to which the difference image has been
saved - it will be a copy of the opponent image overlaid with the
difference between the two images. The filename of the difference
image is computed via the metadata provided during instantiation, with
-diff suffixed as the final component.

    my $diff_file = $screenshot->difference($oppoent);
    `open $diff_file`;

=head2 filename

Get the filename that we constructed for this screenshot. If you
passed in a HASHREF to metadata in the constructor, we'll sort that by
key and concatenate the parts into the filename. If there's no
metadata, we'll use a timestamp for the filename.

If you pass in a HASH as an argument, it will be combined with the
metadata and override/shadow any keys that match.

    # default behavior is to use the timestamp
    Selenium::Screenshot->new(
        png => $driver->screenshot
    )->filename; # screenshots/203523252.png

    # providing any metadata uses that as the filename, and the basis
    # for the diff filename
    Selenium::Screenshot->new(
        png => $driver->screenshot,
        metadata => {
            key => 'value'
        }
    )->filename; # screenshots/value.png

    Selenium::Screenshot->new(
        png => $driver->screenshot,
        metadata => {
            key => 'value'
        }
    )->difference($opponent); # screenshots/value-diff.png

    # overriding the filename
    Selenium::Screenshot->new(
        png => $driver->screenshot,
        metadata => {
            key => 'value'
        }
    )->filename(
        key => 'shadow'
    ); # screenshots/shadow.png

=head2 save

Delegates to L<Imager/write>, which it uses to write to the filename
as calculated by L</filename>. Like L</filename>, you can pass in a
HASH of overrides to the filename if you'd like to customize it.

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Image::Compare|Image::Compare>

=item *

L<Image::Magick|Image::Magick>

=item *

L<Selenium::Remote::Driver|Selenium::Remote::Driver>

=item *

L<https://github.com/bslatkin/dpxdt|https://github.com/bslatkin/dpxdt>

=item *

L<https://github.com/facebook/huxley|https://github.com/facebook/huxley>

=item *

L<https://github.com/BBC-News/wraith|https://github.com/BBC-News/wraith>

=back

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/gempesaw/Selenium-Screenshot/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Daniel Gempesaw.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
