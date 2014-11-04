requires "Carp" => "0";
requires "Cwd" => "0";
requires "Image::Compare" => "0";
requires "Imager" => "0";
requires "Imager::File::PNG" => "0";
requires "Imager::Fountain" => "0";
requires "MIME::Base64" => "0";
requires "Moo" => "0";

on 'test' => sub {
  requires "File::Copy" => "0";
  requires "FindBin" => "0";
  requires "Test::More" => "0";
  requires "strict" => "0";
  requires "warnings" => "0";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.30";
};

on 'develop' => sub {
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};
