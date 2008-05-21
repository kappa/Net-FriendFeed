#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Net::FriendFeed' );
}

diag( "Testing Net::FriendFeed $Net::FriendFeed::VERSION, Perl $], $^X" );
