# @COPYRIGHT@
package Socialtext::File::Stringify::application_pdf;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    $? = 0;
    $@ = undef;
    my $text = Socialtext::System::backtick( "pdftotext", "-enc", "UTF-8", $file,
        "-" );

    if ($ENV{ST_STRINGIFY_TEST}) {
        warn "pdftotext: \$?=($?) \$\@=($@)";
    }
    $text = Socialtext::File::Stringify::Default->to_string($file) if $? or $@;
    return $text;
}

1;
