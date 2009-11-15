#! /usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
use Test::NoWarnings;
use Test::Deep;
use Test::MockHTTP;

use Net::FriendFeed;

my $frf = new Net::FriendFeed;
ok($frf, 'trivial constructor kinda works');
isa_ok($frf, 'Net::FriendFeed', 'trivial constructor works');

can_ok($frf, qw/list_services/);

$frf = Net::FriendFeed->new({ login => 'kkapp', remotekey => 'shlyappa' });
is($frf->login, 'kkapp', 'login set from constructor');
ok($frf->_has_auth, 'auth from the start');

my $frf1 = $frf->new({ return_feeds_as => 'xml' });
isa_ok($frf1, 'Net::FriendFeed', '$obj->constructor works');
is($frf1->return_feeds_as, 'xml', 'init feeds type from constructor');

http_test_setup { $frf->ua($_[0]) };

ok(
http_cmp(sub { $frf->list_services() },
    [
        method => 'GET',
        uri => methods(
            as_string => re('/services$'),
        ),
    ]
), 'list services');
