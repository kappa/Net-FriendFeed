#! /usr/bin/perl

use strict;
use warnings;

use Test::More qw/no_plan/;
use Test::NoWarnings;
use Test::Exception;

use Net::FriendFeed;

my $frf = new Net::FriendFeed;

throws_ok { $frf->return_feeds_as('rss'); } qr/not supported/, 'Old feed formats are not supported';
throws_ok { my $frf1 = $frf->new({ return_feeds_as => 'atom' }); } qr/not supported/, 'Old feed formats are not supported 2';
