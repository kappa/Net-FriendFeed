#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use open qw(:std :utf8);

use Test::More;
use Test::Deep;

use Net::FriendFeed;

sub main {

    if (defined($ENV{FRIENDFEED_LOGIN}) && defined($ENV{FRIENDFEED_REMOTEKEY})) {

        pass('Loaded ok');

        my $nf = Net::FriendFeed->new();
        my $data = $nf->list_services();

        cmp_deeply(
            $data,
            {
                services => ignore()
            },
            'list_services() returns expected data structure'
        );

        cmp_deeply(
            $data->{services}->[0],
            {
                icon => ignore(),
                id => ignore(),
                name => ignore(),
                url => ignore(),
            },
            'First service has expected data structure'
        );

        done_testing();

    } else {
        plan skip_all => 'Need ENV variables FRIENDFEED_LOGIN & FRIENDFEED_REMOTEKEY';
    }

}
main();
__END__
