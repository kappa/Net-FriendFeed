#! /usr/bin/perl

use warnings;
use strict;

use Test::More qw/no_plan/;
use Test::NoWarnings;
use Test::Deep;
use Test::MockObject::Extends;

use LWP::UserAgent;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::Api_EntryPoint = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

TODO: {
local $TODO = 'Rooms are not implemented';

foreach (qw/fetch_room_feed/) {
    can_ok($frf, $_);
}

}
