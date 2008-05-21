use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::FriendFeed',
    license             => 'gpl',
    dist_author         => 'Alex Kapranoff <kappa@cpan.org>',
    dist_version_from   => 'lib/Net/FriendFeed.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Net-FriendFeed-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
