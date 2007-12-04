# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Factory;
use strict;
use warnings;

use Socialtext::l10n qw(system_locale);
use File::Basename 'dirname';
use Socialtext::File 'ensure_directory';
use Socialtext::Search::KinoSearch::Analyzer;
use Socialtext::Search::KinoSearch::Indexer;
use Socialtext::Search::KinoSearch::Searcher;
use Socialtext::Search::Config;
use Socialtext::AppConfig;
use base 'Socialtext::Search::AbstractFactory';

# Rather than create an actual object (since there's no state), just return
# the class name.  This will continue to make all the methods below work.
sub new { $_[0] }

sub create_searcher {
    my ( $self, $ws_name, %param ) = @_;
    return $self->_create( "Searcher", $ws_name, %param );
}

sub create_indexer {
    my ( $self, $ws_name, %param )  = @_;
    return $self->_create( "Indexer", $ws_name, %param );
}

sub _create {
    my $self = shift;
    my ( $kind, $ws_name, %param ) = @_;
    $param{config_type} ||= 'live';
    $param{language}    ||= 'en';
    
    my $config = Socialtext::Search::Config->new(  
        mode => $param{config_type},
    );

    $config or return;
    
    my $class = 'Socialtext::Search::KinoSearch::' . $kind;
    return $class->new( $ws_name, $param{language}, 
        $config->index_directory(workspace => $ws_name),
        $self->_analyzer($param{language}), $config );
}


sub _analyzer {
    my $self = shift;
    my $lang = system_locale();
    return Socialtext::Search::KinoSearch::Analyzer->new( language => $lang );
}

1;
__END__

=pod

=head1 NAME

Socialtext::Search::KinoSearch::Factory

=head1 SEE

L<Socialtext::Search::AbstractFactory> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
