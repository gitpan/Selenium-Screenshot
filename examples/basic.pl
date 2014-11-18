#! /usr/bin/perl

use strict;
use warnings;
use Selenium::Remote::Driver;
use Selenium::Screenshot;

my $driver = Selenium::Remote::Driver->new;

# use smaller size to speed up ->difference call later
$driver->set_window_size(320, 480);

# use page with little vertical height, as firefox currently uses the
# entire height of the page, which will slow down ->difference
$driver->get('http://www.google.com/404');

# Take an original screenshot
my $orig = Selenium::Screenshot->new(
    png => $driver->screenshot,
    metadata => {
        build => 'prod',
        browser => 'firefox',
        keys => 'are sorted alphabetically',
        but => 'are not included in the filename'
    }
);

# Alter the page by turning the background blue
$driver->execute_script('document.getElementsByTagName("body")[0].style.backgroundColor = "blue"');

# Take another screenshot
my $blue_file = Selenium::Screenshot->new(
    png => $driver->screenshot,
    metadata => {
        build => 'stage',
        bg => 'blue',
        url => 'http://www.google.com'
    }
)->save;

unless ($orig->compare($blue_file)) {
    my $diff_file = $orig->difference($blue_file);
    print 'The images differ; see

' . $diff_file . '

for details. We\'ll try to open it for you, but we won\'t try very hard...';

    my $open_cmd;
    if ($^O eq 'darwin') {
        $open_cmd = 'open'
    }
    elsif ($^O eq 'MSWin32') {
        $open_cmd = '';
    }
    else {
        $open_cmd = 'display';
    }
    `$open_cmd $diff_file`;
}
