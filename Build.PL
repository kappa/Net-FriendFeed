use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::FriendFeed',
    license             => 'gpl',
    dist_author         => 'Alex Kapranoff <kappa@cpan.org>',
    dist_version_from   => 'lib/Net/FriendFeed.pm',
    build_requires => {
        'Test::MockObject' => 0,
    },
    requires => {
        'perl' => '5.8.2',
        'LWP::UserAgent' => 0,
        'HTTP::Request::Common' => 0,
        'Class::Accessor' => 0,
        'URI' => 0,
        'JSON' => 2.0,
    },
    add_to_cleanup      => [ 'Net-FriendFeed-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
