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

can_ok($frf, qw/add_comment edit_comment delete_comment undelete_comment add_like delete_like/);

http_test_setup { $frf->ua($_[0]) };

ok(!$frf->add_comment('entry_1', 'haha'), 'add_comment w/o auth');

$frf->login('kappa');
$frf->remotekey('shlyappa');

ok(
http_cmp(sub { $frf->add_comment('entry_1', 'haha!') },
    [
        method => 'POST',
        uri => methods(
            path => re('comment$'),
        ),
        as_string => re('entry=entry_1'),
        as_string => re('body=haha!'),
    ]
), 'add comment');

ok(
http_cmp(sub { $frf->edit_comment('entry_1', 'haha!', 'comment_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('comment$'),
        ),
        as_string => re('entry=entry_1'),
        as_string => re('body=haha!'),
        as_string => re('comment=comment_1'),
    ]
), 'edit comment');

ok(
http_cmp(sub { $frf->delete_comment('entry_1', 'comment_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('comment/delete$'),
        ),
        as_string => re('entry=entry_1'),
        as_string => re('comment=comment_1'),
    ]
), 'delete comment');

ok(
http_cmp(sub { $frf->undelete_comment('entry_1', 'comment_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('comment/delete$'),
        ),
        as_string => re('entry=entry_1'),
        as_string => re('comment=comment_1'),
        as_string => re('undelete=1'),
    ]
), 'undelete comment');

ok(
http_cmp(sub { $frf->add_like('entry_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('like$'),
        ),
        as_string => re('entry=entry_1'),
    ]
), 'add like');

ok(
http_cmp(sub { $frf->delete_like('entry_1') },
    [
        method => 'POST',
        uri => methods(
            path => re('like/delete$'),
        ),
        as_string => re('entry=entry_1'),
    ]
), 'add like');
