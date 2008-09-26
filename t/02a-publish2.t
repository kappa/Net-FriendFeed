#! /usr/bin/perl

use warnings;
use strict;
use utf8;   # strings in Russian present

use Encode;
use URI::Escape qw/uri_escape_utf8/;

use Test::More qw/no_plan/;
use Test::NoWarnings;
use Test::Deep;
use Test::MockHTTP;
use FindBin qw/$Bin/;

use Net::FriendFeed;

our $API_EP = $Net::FriendFeed::API_ENTRYPOINT = 'http://kapranoff.ru/api/';

my $frf = new Net::FriendFeed;

can_ok($frf, qw/publish/);

http_test_setup { $frf->ua($_[0]) };

$frf->login('kappa');
$frf->remotekey('shlyappa');

my $pub_rv;

ok(
http_cmp(sub { $pub_rv = $frf->publish('Message1') },
    [
        method => 'POST',
        uri => methods(as_string => "${API_EP}share"),
        [qw/header Authorization/] => re('Basic \w+'),
        as_string => re('title=Message1'),
    ]
), 'trivial publish()');

ok(ref $pub_rv, 'ref from publish');

sub full_publish {
    $frf->publish(
        message => 'New Futurama seasons!',
        link    => 'http://r0.ru',
        images  => [
            'http://r0.ru/1.gif',
            "$Bin/pod.t",
            ['http://r01.ru/2.gif', 'http://www2.futu'],
            ["$Bin/00-load.t", 'http://mail.rambler.ru'],
        ],
        audios  => [
            'http://r0.ru/podcast.mp3',
            ['http://r0.ru/podcast_intro.mp3' => 'Introduction 1'],
        ],
        room    => 'Room 1',
        via     => 'Perl!',
        comment => 'Hi there!',
    );
}

ok(
http_cmp(\&full_publish,
    [
        method => 'POST',
        uri => methods(as_string => "${API_EP}share"),
        [qw/header Authorization/] => re('Basic \w+'),
        ['header', 'Content-Type'] => re('^multipart/form-data; boundary='),    # gotcha!
        as_string => re('name="title"\r\n\r\nNew Futurama'),
        as_string => re('name="link"\r\n\r\nhttp://r0\.ru'),
        as_string => re('name="comment"\r\n\r\nHi there!'),
        as_string => re('name="image0_url"\r\n\r\n\S+/1\.gif'),
        as_string => re('name="image2_link"\r\n\r\n\S+www2\.futu'),
        as_string => re('name="room"\r\n\r\nRoom 1'),
        as_string => re('name="via"\r\n\r\nPerl!'),
        as_string => re('Content-Disposition: form-data; \S+; filename="pod.t"'),
        as_string => re('Content-Disposition: form-data; \S+; filename="00-load.t"'),
        as_string => re('Content-Disposition: form-data; name="00-load.t_link"\r\n\r\nhttp://mail\.rambler\.ru'),
        as_string => re('name="audio0_url"\r\n\r\n\S+podcast\.mp3'),
        as_string => re('name="audio1_title"\r\n\r\nIntroduction 1'),
    ]
), 'full publish()');
