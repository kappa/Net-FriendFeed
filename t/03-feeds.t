#! /usr/bin/perl

use warnings;
use strict;

use Test::More qw/no_plan/;
use Test::NoWarnings;
use Test::Deep;
use Test::HTTP;

use URI::QueryParam;
use Encode;

use LWP::UserAgent;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::Api_EntryPoint = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

ok(!$frf->ua, 'empty UA by default');
ok($frf->_connect, 'connect');
isa_ok($frf->ua, 'LWP::UserAgent', 'autocreate LWP::UserAgent UA');

http_test_setup { $frf->ua($_[0]) };

can_ok($frf, qw/return_feeds_as/);

is($frf->return_feeds_as(), 'structure', 'default return_feeds_as');

can_ok($frf, qw/fetch_public_feed fetch_user_feed
fetch_user_comments_feed fetch_user_likes_feed
fetch_user_discussion_feed fetch_multi_user_feed fetch_home_feed search fetch_room_feed/);

ok(
http_cmp(sub { $frf->fetch_public_feed() },
    [
        method => 'GET',
        uri => methods(
            as_string => re("^${API_EP}feed/public"),
            query_param => 1,   # 1 param
            ['query_param', 'format'] => 'json',
        ),
    ]
), 'public feed');

ok($frf->return_feeds_as('xml'), 'set return_feeds_as');
is($frf->return_feeds_as, 'xml', 'return_feeds_as set ok');

ok(
http_cmp(sub { $frf->fetch_user_feed('kkapp') },
    [
        uri => methods(
            path => re('feed/user/kkapp$'),
            ['query_param', 'format'] => 'xml',
        ),
    ]
), 'user feed');

$frf->return_feeds_as('structure');

ok(
http_cmp(sub { $frf->fetch_user_comments_feed('kkapp') },
    [
        uri => methods(
            path => re('feed/user/kkapp/comments$'),
        ),
    ]
), 'user comments feed');

ok(
http_cmp(sub { $frf->fetch_user_likes_feed('kkapp') },
    [
        uri => methods(
            path => re('feed/user/kkapp/likes$'),
        ),
    ]
), 'user likes feed');

ok(
http_cmp(sub { $frf->fetch_user_discussion_feed('kkapp') },
    [
        uri => methods(
            path => re('feed/user/kkapp/discussion$'),
        ),
    ]
), 'user discussion feed');

ok(
http_cmp(sub { $frf->fetch_multi_user_feed(['kkapp', 'mihun']) },
    [
        uri => methods(
            path => re('feed/user$'),
            ['query_param', 'nickname'], 'kkapp,mihun',
        ),
    ]
), 'multi user feed');

ok(!$frf->fetch_home_feed, 'home feed w/o auth');

$frf->login('kappa');
$frf->remotekey('shlyappa');

ok(
http_cmp(sub { $frf->fetch_home_feed },
    [
        uri => methods(
            path => re('feed/home$'),
        ),
        [qw/header Authorization/] => re('Basic \w+'),
    ]
), 'home feed');

ok(
http_cmp(sub { $frf->search('rambler service:twitter') },
    [
        uri => methods(
            path => re('feed/search$'),
            [qw/query_param q/], 'rambler service:twitter',
        ),
    ]
), 'search feed');

ok(
http_cmp(sub { $frf->fetch_room_feed('ru-friendfeed') },
    [
        uri => methods(
            path => re('feed/room/ru-friendfeed$'),
        ),
    ]
), 'room feed');
