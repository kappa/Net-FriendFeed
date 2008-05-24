#! /usr/bin/perl
use strict;
use warnings;

use Net::FriendFeed;

my $frf = new Net::FriendFeed { login => 'kkapp', remotekey => 'remo501key' };

$frf->publish_message('Hello, world!');
