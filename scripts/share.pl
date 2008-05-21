#! /usr/bin/perl
use strict;
use warnings;

use Net::FriendFeed;

my $frf = new Net::FriendFeed { login => 'kappak', remotekey => 'zoo550tubas' };

$frf->publish_message('Hello, world!');
