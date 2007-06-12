#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

my $hub = new_hub('admin');

plan tests => 1 * blocks;

for my $block (blocks) {
    $hub->pages->current($block->page);
    my $links = $hub->backlinks->all_backlinks;
    is(scalar(@{$links}), 0, 'no backlinks found because of length');
}

__END__

=== Test One
--- page store_new_page
Subject: 111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

Hello
this is page one to [222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222]
you

Hello [mr chips] and [the son] how are




=== Test Two
--- page store_new_page
Subject: 222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222

Hello
this is page two to [111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111]
you

Goobye John
