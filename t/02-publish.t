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

can_ok($frf, 'publish_message');

ok(!$frf->publish_message('Hello there!'), 'EPERM, need auth');

my $ua = Test::MockObject::Extends->new(LWP::UserAgent->new);
$frf->ua($ua);
$ua->mock(simple_request => sub {
        cmp_deeply($_[1], methods(
                method => 'POST',
                uri => methods(as_string => "${API_EP}share"),
                [qw/header Authorization/] => re('Basic \w+'),
                as_string => re('title=Hello\+there!'),
#                as_string => re('via=Net%3A%3AFriendFeed'),
            )
        );

        return HTTP::Response->new(200, 'Ok');
    }
);

$frf->login('kappa');
$frf->remotekey('shlyappa');

ok($frf->publish_message('Hello there!'), 'ok with auth');

can_ok($frf, 'publish_link');
$ua->mock(simple_request => sub {
        cmp_deeply($_[1], methods(
                method => 'POST',
                uri => methods(as_string => "${API_EP}share"),
                [qw/header Authorization/] => re('Basic \w+'),
                as_string => re('title=Look\+here'),
                as_string => re('link=http%3A%2F%2Fr0\.ru'),
#                as_string => re('via=Net%3A%3AFriendFeed'),
            )
        );

        return HTTP::Response->new(200, 'Ok');
    }
);
ok($frf->publish_link('Look here:', 'http://r0.ru'), 'ok publish_link');

$ua->mock(simple_request => sub {
        cmp_deeply($_[1], methods(
                as_string => re('image0_url=\S+rambler\.gif'),
            )
        );

        return HTTP::Response->new(200, 'Ok');
    }
);
ok($frf->publish_link('Look here:', 'http://r0.ru',
    ['http://images.rambler.ru/lt/rambler.gif']), 'ok publish_link w/ img');

$ua->mock(simple_request => sub {
        cmp_deeply($_[1], methods(
                as_string => re('image1_link=\S+mail\.rambler\.ru'),
            )
        );

        return HTTP::Response->new(200, 'Ok');
    }
);
ok($frf->publish_link('Look here:', 'http://r0.ru',
    ['http://images.rambler.ru/lt/rambler.gif',
        ['http://images.rambler.ru/lt/rambler.gif', 'http://mail.rambler.ru']
    ]), 'ok publish_link w/ img');
