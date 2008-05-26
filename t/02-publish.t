#! /usr/bin/perl

use warnings;
use strict;
use utf8;   # strings in Russian present

use Encode;
use URI::Escape qw/uri_escape_utf8/;

use Test::More qw/no_plan/;
use Test::NoWarnings;
use Test::Deep;
use Test::HTTP;
use FindBin qw/$Bin/;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::API_ENTRYPOINT = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

can_ok($frf, qw/publish_message publish_link/);

http_test_setup { $frf->ua($_[0]) };

ok(!$frf->_has_auth, 'no auth present');

ok(!$frf->publish_message('Hello there!'), 'EPERM, need auth');

$frf->login('kappa');

ok(!$frf->publish_message('Hello there!'), 'EPERM, need more auth');

$frf->remotekey('shlyappa');

ok($frf->_has_auth, 'auth');

my $pub_rv;

ok(
http_cmp(sub { $pub_rv = $frf->publish_message('Hello there!') },
    [
        method => 'POST',
        uri => methods(as_string => "${API_EP}share"),
        [qw/header Authorization/] => re('Basic \w+'),
        as_string => re('title=Hello\+there!'),
    ]
), 'ok with auth');

ok(ref $pub_rv, 'ref from publish');

$frf->return_feeds_as('atom');

=for example
$frf->publish_link($title, $link, $comment, [@images, [$imgN, $linkN]], $room, $via)
XXX upload images directly
=cut

ok(
http_cmp(sub { $pub_rv = $frf->publish_link('Look here:', 'http://r0.ru') },
    [
        method => 'POST',
        uri => methods(as_string => "${API_EP}share?format=atom"),
        [qw/header Authorization/] => re('Basic \w+'),
        as_string => re('title=Look\+here'),
        as_string => re('link=http%3A%2F%2Fr0\.ru'),
    ]
), 'ok publish_link');

ok(!ref $pub_rv, 'no ref from publish');

$frf->return_feeds_as('structure');

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
http_cmp( sub { $frf->publish_link('Look here:', 'http://r0.ru', undef, 'bad images') },
    [
        ['header', 'Content-Type'] => 'application/x-www-form-urlencoded', # still no multipart
        as_string => code(sub { $_[0] !~ /image/ }),
    ]
), 'ok publish_link w/ bad imgs');

ok(
http_cmp( sub { $frf->publish_link('Look here:', 'http://r0.ru', undef, ['http://images.rambler.ru/lt/rambler.gif',
            ['http://images.rambler.ru/lt/rambler.gif', 'http://mail.rambler.ru']]) },
    [
        ['header', 'Content-Type'] => 'application/x-www-form-urlencoded', # still no multipart
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
http_cmp( sub { $frf->publish_link('Look here:', 'http://r0.ru', undef, ["$Bin/pod.t",
            ["$Bin/00-load.t", 'http://mail.rambler.ru']]) },
    [
        ['header', 'Content-Type'] => re('^multipart/form-data; boundary='),    # gotcha!
        as_string => re('Content-Disposition: form-data; \S+; filename="pod.t"'),
        as_string => re('Content-Disposition: form-data; \S+; filename="00-load.t"'),
        as_string => re('Content-Disposition: form-data; name="00-load.t_link"\r\n\r\nhttp://mail\.rambler\.ru'),
    ]
), 'ok publish_link w/ img from files');

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

ok(
!http_cmp(sub { $pub_rv = $frf->publish_message('Hello there!') },
    [
        as_string => re('title=Hello\+there!'),
    ], undef,
    HTTP::Response->new(500, 'Hehe'),
), 'bad response');
