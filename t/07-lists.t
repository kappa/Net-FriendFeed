#! /usr/bin/perl

use warnings;
use strict;

use Test::More skip_all => 'Lists will be implemented after APIv2';
use Test::NoWarnings;
use Test::Deep;
use Test::MockHTTP;

use LWP::UserAgent;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::API_ENTRYPOINT = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed ({ login => 'kappa', remotekey => 'shlyappa' });

http_test_setup { $frf->ua($_[0]) };

can_ok($frf, qw/fetch_list_profile fetch_list_feed/);

ok(
http_cmp(sub { $frf->fetch_list_profile('list1') },
    [
        uri => methods(
            path => re('list/list1/profile$'),
        ),
    ]
), 'fetch list profile');

ok(
http_cmp(sub { $frf->fetch_list_feed('list1') },
    [
        uri => methods(
            path => re('feed/list/list1$'),
        ),
    ]
), 'fetch list feed');
