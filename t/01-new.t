#! /usr/bin/perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::NoWarnings;

use Net::FriendFeed;

my $frf = new Net::FriendFeed;
ok($frf, 'trivial constructor kinda works');
isa_ok($frf, 'Net::FriendFeed', 'trivial constructor works');

$frf = Net::FriendFeed->new({ login => 'kkapp', remotekey => 'shlyappa' });
is($frf->login, 'kkapp', 'login set from constructor');
ok($frf->_has_auth, 'auth from the start');
