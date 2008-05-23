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
local $TODO = "Feeds are not implemented";

foreach (qw/fetch_public_feed fetch_user_feed fetch_user_comments_feed
    fetch_user_likes_feed fetch_user_discussion_feed fetch_multi_user_feed fetch_home_feed
    search/) {
    can_ok($frf, $_);
}

}
