#! /usr/bin/perl

use warnings;
use strict;

use Test::More tests => 8;
use Test::NoWarnings;
use Test::Deep;
use Test::MockHTTP;

use URI::QueryParam;

use LWP::UserAgent;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::API_ENTRYPOINT = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

can_ok($frf, qw/fetch_user_profile fetch_user_profiles/);

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

ok(
http_cmp(sub { $frf->fetch_user_profiles(qw/kkapp mihun/) },
    [
        method => 'GET',
        uri => methods(
            path => re('profiles$'),
            ['query_param', 'nickname'], 'kkapp,mihun',
        ),
    ]
), 'multi user profiles feed w/o arrayref');

ok(
http_cmp(sub { $frf->fetch_user_profiles(['kkapp', 'mihun']) },
    [
        method => 'GET',
        uri => methods(
            path => re('profiles$'),
            ['query_param', 'nickname'], 'kkapp,mihun',
        ),
    ]
), 'multi user profiles feed');
