#! /usr/bin/perl

use strict;
use warnings;
use File::Copy;
use FindBin;
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

SAVING: {
    my $res = $screenshot->save;
    ok($res, 'can save a screenshot');
    ok(-e $screenshot->filename, 'and it actually exists');
    ok($screenshot->filename =~ /screenshots/, 'where we expect it to');

}

METADATA: {
    my $meta_args = $basic_args;
    $meta_args->{metadata} = {
        url     => 'http://fake.url.com',
        build   => 'random-12347102.238402-build',
        browser => 'firefox'
    };
    my $meta_shot = Selenium::Screenshot->new(%$meta_args);
    my $filename = $meta_shot->save;
    ok($filename =~ /fake.url/, 'meta data is used in filename');
    ok($filename =~ /random\-1234/, 'meta data is used in filename');
    ok($filename =~ /firefox/, 'meta data is used in filename');
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

COMPARE: {
    my $sample_png = $FindBin::Bin . '/sample.png';

    open (my $image_fh, "<", $sample_png) or die 'cannot open: ' . $!;
    my $png_string = do{ local $/ = undef; <$image_fh>; };
    close ($image_fh);

    my $screenshot = Selenium::Screenshot->new(
        png => encode_base64($png_string),
        metadata => {
            test => 'compare'
        }
    );

    ok($screenshot->compare($sample_png), 'comparing to self passes');

    my $different = $FindBin::Bin . '/sample-diff.png';
    ok(!$screenshot->compare($different),
       'comparing two different images fails!');
  CONTRAST: {
        # get the difference file
        my $diff_file = $screenshot->difference($different);
        ok( -e $diff_file, 'diff file exists' );
        ok( $diff_file =~ /-diff\.png/, 'diff is named differently' );
    }
}

CLEANUP: {
    my @leftover_files = glob($fixture_dir . '*');
    map { unlink } @leftover_files;
    rmdir $fixture_dir;
}

done_testing;
