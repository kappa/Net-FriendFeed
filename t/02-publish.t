#! /usr/bin/perl

use warnings;
use strict;
use utf8;   # strings in Russian present

use Encode;
use URI::Escape qw/uri_escape_utf8/;

use Test::More tests => 21;
use Test::NoWarnings;
use Test::Deep;
use Test::HTTP;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::API_ENTRYPOINT = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

can_ok($frf, qw/publish_message publish_link/);

http_test_setup { $frf->ua($_[0]) };

ok(!$frf->_need_auth, 'no auth present');

ok(!$frf->publish_message('Hello there!'), 'EPERM, need auth');

$frf->login('kappa');
$frf->remotekey('shlyappa');

ok($frf->_need_auth, 'auth');

ok(
http_cmp(sub { $frf->publish_message('Hello there!') },
    [
        method => 'POST',
        uri => methods(as_string => "${API_EP}share"),
        [qw/header Authorization/] => re('Basic \w+'),
        as_string => re('title=Hello\+there!'),
    ]
), 'ok with auth');

=for example
$frf->publish_link($title, $link, $comment, [@images, [$imgN, $linkN]], $room, $via)
XXX upload images directly
=cut

ok(
http_cmp(sub { $frf->publish_link('Look here:', 'http://r0.ru') },
    [
        method => 'POST',
        uri => methods(as_string => "${API_EP}share"),
        [qw/header Authorization/] => re('Basic \w+'),
        as_string => re('title=Look\+here'),
        as_string => re('link=http%3A%2F%2Fr0\.ru'),
    ]
), 'ok publish_link');

ok(
http_cmp(sub { $frf->publish_link('Look here:', 'http://r0.ru', 'This is Rambler-Lite home page') },
    [
        as_string => re('comment=This\+is\+Rambler-Lite'),
    ]
), 'ok publish_link w/ comment');


ok(
http_cmp(sub { $frf->publish_link('Look here:', 'http://r0.ru', 'cmnt2',
            ['http://images.rambler.ru/lt/rambler.gif']) },
    [
        as_string => re('image0_url=\S+rambler\.gif'),
        as_string => re('comment=cmnt2'),
    ]
), 'ok publish_link w/ img & comment');

ok(
http_cmp( sub { $frf->publish_link('Look here:', 'http://r0.ru', undef, ['http://images.rambler.ru/lt/rambler.gif',
            ['http://images.rambler.ru/lt/rambler.gif', 'http://mail.rambler.ru']]) },
    [
        as_string => re('image1_link=\S+mail\.rambler\.ru'),
    ]
), 'ok publish_link w/ img and special img-link');

ok(
http_cmp(sub { $frf->publish_link('Look here:', 'http://r0.ru', undef, undef, 'Dining Room') },
    [
        as_string => re('room=Dining\+Room'),
        as_string => code(sub { $_[0] !~ 'image' }),
    ]
), 'ok publish_link to room and old args are not kept');

ok(
http_cmp(sub { $frf->publish_link('Look here:', 'http://r0.ru', undef, undef, 'Dining Room', 'Perl!') },
    [
        as_string => re('room=Dining\+Room'),
        as_string => re('via=Perl!'),
    ]
), 'ok publish_link to room and via');

ok(
http_cmp(sub { $frf->publish_message('Рамблер ftw!') },
    [
        as_string => re('title=' . uri_escape_utf8('Рамблер') . '\+ftw!'),
    ]
), 'publish non-ASCII data');

