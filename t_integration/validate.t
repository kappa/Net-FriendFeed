#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use open qw(:std :utf8);

use Test::More;
use Test::Deep;

use Net::FriendFeed;

sub check_correct_credentials {
    my (%params) = @_;

    my $nf = Net::FriendFeed->new(
        login => $params{login},
        remotekey => $params{remotekey},
    );

    cmp_deeply(
        $nf->validate(),
        {
            id   => $ENV{FRIENDFEED_LOGIN},
            name => ignore(),
            type => "user",
        },
        'Got correct user data from validate() method',
    );

}

sub check_incorrect_credentials {

    my $nf = Net::FriendFeed->new(
        login => 'no_such_user',
        remotekey => 'incorrect_remote_key',
    );

    cmp_deeply(
        scalar $nf->validate(),
        undef,
        'Got undef from validate() method when used with incorrect remotekey',
    );

    cmp_deeply(
        $nf->last_error(),
        'unauthorized',
        'Got "unauthorized" message from last_error()',
    );

}

sub main {

    if (defined($ENV{FRIENDFEED_LOGIN}) && defined($ENV{FRIENDFEED_REMOTEKEY})) {

        pass('Loaded ok');

        check_correct_credentials(
            login => $ENV{FRIENDFEED_LOGIN},
            remotekey => $ENV{FRIENDFEED_REMOTEKEY},
        );

        check_incorrect_credentials();

        done_testing();

    } else {
        plan skip_all => 'Need ENV variables FRIENDFEED_LOGIN & FRIENDFEED_REMOTEKEY';
    }

}
main();
__END__
