#! /usr/bin/perl

use warnings;
use strict;

use Test::More qw/no_plan/;
use Test::NoWarnings;
use Test::Deep;
use Test::HTTP;

use LWP::UserAgent;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::Api_EntryPoint = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

can_ok($frf, 'fetch_user_profile');

http_test_setup { $frf->ua($_[0]) };

ok(
http_cmp(sub { $frf->fetch_user_profile('kkapp') },
    [
        method => 'GET',
        uri => methods(
            path => re('user/kkapp/profile$'),
        ),
    ]
), 'user profile feed');
