#! /usr/bin/perl

use strict;
use warnings;
use File::Copy;
use FindBin;
use Imager;
use MIME::Base64;
use Test::More;

BEGIN: {
    unless (use_ok('Selenium::Screenshot')) {
        BAIL_OUT("Couldn't load Selenium::Screenshot");
        exit;
    }
}

my $string = 'fake-encoded-string';
my $fixture_dir = $FindBin::Bin . '/screenshots/';

my $basic_args = {
    png => encode_base64($string),
    folder => $fixture_dir
};
my $screenshot = Selenium::Screenshot->new(%$basic_args);

my $sample_png = $FindBin::Bin . '/sample.png';

open (my $image_fh, "<", $sample_png) or die 'cannot open: ' . $!;
my $png_string = encode_base64( do{ local $/ = undef; <$image_fh>; } );
close ($image_fh);

FILENAME: {
    my $timestamp = Selenium::Screenshot->new(
        %$basic_args
    )->filename;
    cmp_ok($timestamp , '=~', qr/\d+\.png/, 'filename works for timestamp');

    my $metadata = Selenium::Screenshot->new(
        %$basic_args,
        metadata => {
            key => 'value'
        }
    )->filename;
    cmp_ok($metadata , '=~', qr/value\.png/, 'filename works for metadata');

    my $shadow = Selenium::Screenshot->new(
        %$basic_args,
        metadata => {
            key => 'value'
        }
    )->filename(
        key => 'shadow'
    );
    cmp_ok($shadow , '=~', qr/shadow\.png/, 'filename works for shadowed metadata');
}

METADATA: {
    my $meta_args = $basic_args;
    $meta_args->{png} = $png_string;
    $meta_args->{metadata} = {
        url     => 'http://fake.url.com',
        build   => 'random-12347102.238402-build',
        browser => 'firefox'
    };
    my $meta_shot = Selenium::Screenshot->new(%$meta_args);
    my $filename = $meta_shot->save(override => 'extra');
    ok(-e $filename, 'save function writes to disk');
    ok($filename =~ /fake.url/, 'meta data is used in filename');
    ok($filename =~ /random\-1234/, 'meta data is used in filename');
    ok($filename =~ /firefox/, 'meta data is used in filename');
    ok($filename =~ /extra/, 'override metadata is used in filename');
}

DIRTY_STRINGS: {
    my %tests = (
        'pass-through.123'                => 'pass-through.123',
        'spaces '                         => 'spaces-',
        'http://www.url-like.com'         => 'http---www.url-like.com',
        'builds-pass-4.7.4.20141030-1916' => 'builds-pass-4.7.4.20141030-1916'
    );

    foreach (keys %tests) {
        my $cleaned = $screenshot->_sanitize_string($_);
        cmp_ok($cleaned, 'eq', $tests{$_}, $_ . ' is properly sanitized');
    }
}

WITH_REAL_PNG: {
    my $screenshot = Selenium::Screenshot->new(
        png => $png_string,
        metadata => {
            test => 'compare',
            and  => 'diff'
        }
    );
    my $different = $FindBin::Bin . '/sample-diff.png';

  COMPARE: {
        ok($screenshot->compare($sample_png), 'comparing to self passes');
        ok(!$screenshot->compare($different), 'comparing two different images fails!');
    }

  CONTRAST: {
        # get the difference file
        my $diff_file = $screenshot->difference($different);
        ok( -e $diff_file, 'diff file exists' );
        cmp_ok( $diff_file, '=~', qr/-diff\.png/, 'diff is named differently' );
    }

  CASTING: {
        my $file = $FindBin::Bin . '/sample.png';
        my $tests = {
            file => $file,
            imager => Imager->new(file => $file),
            screenshot => Selenium::Screenshot->new(png => $png_string)
        };

        foreach my $type (keys %$tests) {
            my $extracted = Selenium::Screenshot->_extract_image($tests->{$type});
            ok($extracted->isa('Imager'), 'we can convert ' . $type . ' to Imager');
        }
    }

  EXCLUDE: {
      UNIT: {
            my $exclude = [{
                size     => { width => 8, height => 8 },
                location => { x => 4, y => 4 }
            }, {
                size     => { width => 1, height => 1 },
                location => { x => 0, y => 0 }
            }];

            my $img = Imager->new(file => $sample_png);
            my $copy = $img->copy;

            $img = Selenium::Screenshot->_img_exclude($img, $exclude);

            my $cmp = Image::Compare->new(method => &Image::Compare::EXACT);
            $cmp->set_image1(img => $img, type => 'PNG');
            $cmp->set_image2(img => $copy, type => 'PNG');
            ok( ! $cmp->compare, 'exclusion makes images different' );

            $copy = Selenium::Screenshot->_img_exclude($copy, $exclude);
            $cmp->set_image2(img => $copy, type => 'PNG');

            ok( $cmp->compare, 'excluding two images makes them the same' );
        }

      E2E: {
            my $exclude = [{
                size => { width => 16, height => 16 },
                location => { x => 0, y => 0 }
            }];

            my $exclude_shot = Selenium::Screenshot->new(
                png => $png_string,
                exclude => $exclude
            );

            my $copy = $screenshot->png;
            ok( $exclude_shot->compare($screenshot), 'we automatically exclude the opponent as well');
            ok( $screenshot->compare($copy), 'without mutating the opponent');

            # The exclusion is done during the construction of the
            # _cmp attribute of Selenium::Screenshot. While it is
            # implicitly called behind the scenes automatically by
            # compare, it needs to be lazy due to its dependencies. If
            # you need to move this section above the
            # $exclude_shot->compare invocation, you must manually
            # instantiate $exclude_shot->_cmp.
            my $cmp = Image::Compare->new(method => &Image::Compare::EXACT);
            $cmp->set_image1(type => 'PNG', img => $exclude_shot->png );
            $cmp->set_image2(type => 'PNG', img => $screenshot->png );
            ok( ! $cmp->compare, 'having an exclusion in the constructor mutates its own png');
        }

    }
}

CLEANUP: {
    my @leftover_files = glob($fixture_dir . '*');
    map { unlink } @leftover_files;
    rmdir $fixture_dir;
}

done_testing;
