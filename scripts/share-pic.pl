#! /usr/bin/perl
use strict;
use warnings;

use Encode;
use utf8;

use Net::FriendFeed;

my $frf = new Net::FriendFeed { login => 'kkapp', remotekey => 'gibes12amend' };
#my $frf = new Net::FriendFeed { login => 'kappak', remotekey => 'zoo550tubas' };

$frf->publish_link(Encode::encode('utf-8', 'Последний в этом сезоне Хаус (seeds: 14462, leechers: 4304'),
    'http://isohunt.com/torrents/?ihq=house+s04e16',
    ['http://de6.pictaboo.com/f/8/v69e83b88t74i69q83b89d72f72i69.jpg']);
