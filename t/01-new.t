#! /usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::NoWarnings;
use Test::Deep;
use Test::MockHTTP;
use Test::Exception;

use Net::FriendFeed;

my $frf = new Net::FriendFeed;
ok($frf, 'trivial constructor kinda works');
isa_ok($frf, 'Net::FriendFeed', 'trivial constructor works');

can_ok($frf, qw/list_services/);

$frf = Net::FriendFeed->new(login => 'kkapp', remotekey => 'shlyappa');
is($frf->login, 'kkapp', 'login set from constructor');
ok($frf->_has_auth, 'auth from the start');

lives_ok { $frf = Net::FriendFeed->new({login => 'kkapp', remotekey => 'shlyappa'}) }
    'hashref call does not die';
ok($frf, 'hashref call creates object');

throws_ok { Net::FriendFeed->new(1,2,3) } qr/Incorrect/, 'Odd
    number of arguments to new';

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
