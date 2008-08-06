# @COPYRIGHT@
package Socialtext::Skin;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Plugin';
use File::Basename qw(dirname);
use Socialtext::URI;
use Socialtext::AppConfig;
use Socialtext;
use File::Spec;
use YAML;

our $CODE_BASE = Socialtext::AppConfig->code_base;
our $PROD_VER = Socialtext->product_version();
our $DEFAULT_PARENT = 's2';
my %css_files = (
    standard => [qw(screen.css screen.ie.css print.css print.ie.css)],
    popup    => [qw(popup.css popup.ie.css)],
    wikiwyg  => [qw(wikiwyg.css)],
);

sub class_id { 'skin' }

# Returns an array of full paths to the preloaded templates
sub PreloadTemplateDirs {
    my $class = shift;
    return glob($class->_path('skin', '*', 'template'));
}

sub template_paths {
    my ($self,$skin) = @_;
    my $info = $self->skin_info($skin);
    return [
        grep { -d $_ }
        map { $self->skin_path($_) . '/template' }
        reverse $self->inheritence($skin)
    ];
}

sub skin_info {
    my ($self, $skin) = @_;
    $skin ||= $self->current_skin;
    return $self->{_skin_info}{$skin} if $self->{_skin_info}{$skin};
    my $skin_path = $skin =~ m{^uploaded-skin/}
        ? $self->_path($skin)
        : $self->skin_path($skin);
    my $info_path = File::Spec->catfile( $skin_path, 'info.yaml' );
    $self->{_skin_info} = -f $info_path ? YAML::LoadFile($info_path) : {};
    $self->{_skin_info}{parent} ||= $DEFAULT_PARENT;
    $self->{_skin_info}{skin_name} = $skin;
    $self->{_skin_info}{skin_path} = $skin_path;
    unless (defined $self->{_skin_info}{cascade_css}) {
        $self->{_skin_info}{cascade_css} =
            $self->hub->current_workspace->cascade_css;
    }
    return $self->{_skin_info};
}

sub inheritence {
    my ($self,$skin) = @_;
    $skin ||= $self->current_skin;

    return @{$self->{_inheritence}{$skin}} if $self->{_inheritence}{$skin};

    my %done;
    my @inherit;
    while ($skin and not $done{$skin}) {
        $done{$skin} = 1; # protect against infinit loops
        my $info = $self->skin_info($skin);
        push @inherit, $skin;
        $skin = $info->{parent};
    }
    $self->{_inheritence}{$skin} = \@inherit;
    return @inherit;
}

sub css_info {
    my $self = shift;
    my $skin_info = $self->skin_info;

    my %files;

    my $add_common = 1;

    for my $skin ($self->inheritence) {
        my $info = $self->skin_info($skin);

        my $skin_path = $self->skin_path($skin);
        my $skin_uri = $self->skin_uri($skin);

        while (my ($sec,$files) = each %css_files) {
            unshift @{$files{$sec}}, map  { "$skin_uri/css/$_" }
                                     grep { -f "$skin_path/css/$_" }
                                     @$files;
        }

        $add_common = 0 if $info->{no_common};
        last unless $info->{cascade_css};
    }

    # Common CSS
    if ($add_common) {
        push @{$files{common}}, $self->_uri('skin/common/css/common.css');
    }

    return \%files;
}

sub css_files {
    my $self = shift;

    my $info = $self->css_info;

    my @files;
    for my $paths (values %$info) {
        for my $path (@$paths) {
            if (my ($skin, $file) = $path =~ m{skin/([^/]+)/css/(.*)}) {
                push @files, $self->_path("skin/$skin/css/$file");
            }
        }
    }

    return @files;
}

sub current_skin {
    my $self = shift;
    if ($self->hub->current_workspace->uploaded_skin) {
        my $ws = $self->hub->current_workspace->name;
        return "uploaded-skin/$ws";
    }
    else {
        return $self->hub->current_workspace->skin_name;
    }
}

sub skin_upload_path {
    my $self = shift;
    my $ws = $self->hub->current_workspace->name;
    return $self->_path("uploaded-skin/$ws");
}

sub skin_path {
    my $self = shift;
    my $skin = shift || $self->current_skin;
    if ($skin =~ m{^(?:skin|uploaded-skin)/}) {
        return $self->_path($skin);
    }
    return $self->_path('skin', $skin);
}

sub skin_uri {
    my $self = shift;

    my $skin = shift || $self->current_skin;
    if ($skin =~ m{^(?:skin|uploaded-skin)/}) {
        return $self->_uri($skin);
    }
    return $self->_uri('skin', $skin);
}

sub customjs {
    my $self = shift;
    my ($uri, $name);

    # Ignore customjs_name and customjs_uri if we're using an uploaded skin
    unless ($self->hub->current_workspace->uploaded_skin) {
        $uri = $self->hub->current_workspace->customjs_uri;
        $name = $self->customjs_name;
    }

    unless ($uri) {
        my $path = $self->skin_path($name);
        if (-f "$path/javascript/custom.js") {
            $uri = $self->skin_uri($name) . '/javascript/custom.js';
        }
    }

    return $uri;
}

sub skin_name {
    my $self = shift;
    require Apache::Cookie;
    return $self->{skin_name}
        if defined $self->{skin_name};
    my $skin_name;
    my $self_uri = Socialtext::URI::uri();
    if ( Apache::Cookie->can('fetch') ) {
        my $cookies = Apache::Cookie->fetch;
        if ($cookies) {
            my $cookie = $cookies->{'socialtext-skin'};
            if ($cookie) {
                $skin_name = $cookie->value;
            }
        }
    }
    return $skin_name ||
        $self->hub->current_workspace->skin_name;
}

sub cascade_css {
    my $self = shift;
    my $cascade = $self->skin_info->{cascade_css};
    return defined $cascade ? $cascade : 
                              $self->hub->current_workspace->cascade_css;
}

sub customjs_name {
    my $self = shift;
    return $self->skin_info->{customjs_name} ||
        $self->hub->current_workspace->customjs_name;
}

sub header_logo_image_uri {
    my $self = shift;

    my $logo_file = Socialtext::File::catfile(
        $CODE_BASE, 'images',
        $self->skin_name, 'logo-bar-12.gif' );

    if ( -f $logo_file ) {
        return join '/',
            Socialtext::Helpers->static_path,
            'images',
            $self->skin_name,
            'logo-bar-12.gif';
    }

    return join '/',
        Socialtext::Helpers->static_path,
        'images',
        'logo-bar-12.gif';
}

sub make_dirs {
    my ($self, $skin) = @_;
    return 
        map { dirname($_) }
        grep { -f $_ }
        map { $self->_path("skin/$_/javascript/Makefile") }
        $self->inheritence($skin);
}

sub _path {
    my $self = shift;
    return File::Spec->catdir( $CODE_BASE, @_ );
}

sub _uri {
    my $self = shift;
    return join('/', '', 'static', $PROD_VER, @_);
}

1;
