#! /usr/bin/perl

use warnings;
use strict;

use Test::More tests => 12;
use Test::NoWarnings;
use Test::Deep;
use Test::MockHTTP;

use URI::QueryParam;
use Encode;

use LWP::UserAgent;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::API_ENTRYPOINT = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed ({ login => 'kappa', remotekey => 'shlyappa' });

http_test_setup { $frf->ua($_[0]) };

can_ok($frf, qw/fetch_entry delete_entry undelete_entry hide_entry
    unhide_entry/);

ok(
http_cmp(sub { $frf->fetch_entry('88601999-bb6c-eeb3-ad73-ec3359bab5de') },
    [
        uri => methods(
            path => re('feed/entry/88601999-bb6c-eeb3-ad73-ec3359bab5de$'),
        ),
    ]
), 'fetch single entry');

ok(
http_cmp(sub { $frf->delete_entry('entry_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('entry/delete$'),
        ),
        as_string => re('entry=entry_1'),
    ]
), 'delete entry');

ok(
http_cmp(sub { $frf->undelete_entry('entry_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('entry/delete$'),
        ),
        as_string => re('entry=entry_1'),
        as_string => re('undelete=1'),
    ]
), 'undelete entry');

ok(
http_cmp(sub { $frf->hide_entry('entry_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('entry/hide$'),
        ),
        as_string => re('entry=entry_1'),
    ]
), 'hide entry');

ok(
http_cmp(sub { $frf->unhide_entry('entry_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('entry/hide$'),
        ),
        as_string => re('entry=entry_1'),
        as_string => re('unhide=1'),
    ]
), 'unhide entry');
