package Test::HTTP;

use warnings;
use strict;

=head1 NAME

Test::HTTP - utility to test LWP usage without actual HTTP requests

=cut

use Test::MockObject::Extends;
use Test::Deep;
use LWP::UserAgent;

use base qw/Exporter/;

our @EXPORT = qw/http_cmp http_test_setup/;

my $Http_test_setup;
my $Mock_ua;

=head1 SYNOPSIS

    use Test::HTTP;

    my $ua;
    http_test_setup { $ua = $_[0] };

    http_cmp( sub { $ua->do_some_http_request() },
        [
            as_string => re('image1_link=\S+mail\.rambler\.ru'),
            # these are pairs of method => test againt its return
            # value
        ]
    );
    ...

=cut

=head1 FUNCTIONS

=head2 http_test_setup

This function takes one coderef argument which gets called with a
specially crafted (with mocked methods) LWP::UserAgent instance before
each test. All actions should use this UA to be tested.

=cut

sub http_test_setup(&) {
    $Http_test_setup = shift;
}

=head2 http_cmp
This is a wrapper around Test::Deep::cmp_deeply which does the actual
tests.

It takes 4 arguments.

=over 2

=item $code

This is the code to test. It gets called.

=item $methods

This is an arrayref of pairs 'method' => 'test against its return
value'. It gets passed into Test::Deep::methods to construct a test
against HTTP::Request which is provided by LWP.

=item $msg

TAP message, is directly passed to Test::Deep::cmp_deeply.

=item $resp

HTTP::Response instance which is returned as a fake response to HTTP::Request
from simple_request() method. Defaults to simple '200 Ok' empty
response.

=back

=cut

sub http_cmp {
    my ($code, $methods, $msg, $resp) = @_;

    $Http_test_setup->($Mock_ua) if $Http_test_setup;

    $Mock_ua->mock(simple_request => sub {
        cmp_deeply($_[1], methods(@$methods), $msg);

        return $resp || HTTP::Response->new(200, 'Ok',
            [Server => 'mock'], '{"result": "ok"}');    # JSON
    });

    $code->();
}

$Mock_ua = Test::MockObject::Extends->new(LWP::UserAgent->new);
