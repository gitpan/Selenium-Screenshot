
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.014.
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Compare and contrast Webdriver screenshots in PNG format",
  "AUTHOR" => "Daniel Gempesaw <gempesaw\@gmail.com>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Selenium-Screenshot",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "Selenium::Screenshot",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "Image::Compare" => 0,
    "Imager" => 0,
    "Imager::Color" => 0,
    "Imager::File::PNG" => 0,
    "Imager::Fountain" => 0,
    "MIME::Base64" => 0,
    "Moo" => 0,
    "Scalar::Util" => 0
  },
  "TEST_REQUIRES" => {
    "File::Copy" => 0,
    "FindBin" => 0,
    "Test::More" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.03",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Cwd" => 0,
  "File::Copy" => 0,
  "FindBin" => 0,
  "Image::Compare" => 0,
  "Imager" => 0,
  "Imager::Color" => 0,
  "Imager::File::PNG" => 0,
  "Imager::Fountain" => 0,
  "MIME::Base64" => 0,
  "Moo" => 0,
  "Scalar::Util" => 0,
  "Test::More" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



