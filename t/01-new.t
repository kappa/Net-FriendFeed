#! /usr/bin/perl

use strict;
use warnings;

use Test::More tests => 3;
use Test::NoWarnings;

use Net::FriendFeed;

my $frf = new Net::FriendFeed;
ok($frf, 'trivial constructor kinda works');
isa_ok($frf, 'Net::FriendFeed', 'trivial constructor works');

