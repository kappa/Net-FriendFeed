package Net::FriendFeed;

use warnings;
use strict;

=head1 NAME

Net::FriendFeed - Perl interface to FriendFeed.com API

=cut

our $VERSION = '2.01';

use Encode;
use File::Spec;
use HTTP::Request::Common;
use LWP::UserAgent;
use MIME::Base64 qw/encode_base64/;
use URI::Escape;
use Carp;

#Net::FriendFeed->mk_accessors(qw/login remotekey ua return_feeds_as last_error/);

our $API1_ENTRYPOINT = 'http://friendfeed.com/api/';
our $API_ENTRYPOINT = 'http://friendfeed-api.com/v2/';

our $Last_Http_Response;

=head1 SYNOPSIS

FriendFeed is a social feed agregator with a clean public REST-based
API. This package allows easy access to FriendFeed from Perl.

Methods are named in accordance with the official Python package.

    use Net::FriendFeed;

    my $frf = Net::FriendFeed->new;
    $frf->publish_message('Hello, world!');
    ...

=cut

=head1 GENERAL FUNCTIONS

=head2 new(\%opts) or new(%opts)

This is a constructor for FriendFeed object. It takes an optional
hashref parameter with auth credentials.

Example:

    my $frf_anon = Net::FriendFeed->new;
    my $frf = Net::FriendFeed->new(login => 'kkapp', remotekey => 'hfytr38');
    my $frf = Net::FriendFeed->new({login => 'kkapp', remotekey => 'hfytr38'});

The remotekey is a kind of easily regeneratable password used
only in API functions. A user can get his remotekey here:
L<http://friendfeed.com/remotekey>

Authentication is needed only to post or to read private feeds.

=head2 last_error()

Returns machine-readable code of the last error. You should consult
this code if an API call returns C<undef>.

This is a list of FriendFeed error codes:
    * bad-id-format - Bad format for UUID argument.
    * bad-url-format - Bad format for URL argument.
    * entry-not-found - Entry with the specified UUID was not found.
    * entry-required - Entry UUID argument is required.
    * forbidden - User does not have access to entry, room or other entity specified in the request.
    * image-format-not-supported - Unsupported image format.
    * internal-server-error - Internal error on FriendFeed server.
    * limit-exceeded - Request limit exceeded.
    * room-not-found - Room with specified name not found.
    * room-required - Room name argument is required.
    * title-required - Entry title argument is required.
    * unauthorized - The request requires authentication.
    * user-not-found - User with specified nickname not found.
    * user-required - User nickname argument is required.
    * error - Other unspecified error.

These error codes are generated inside Net::FriendFeed wrapper code:
    * need-auth - The request was not made because it requires authentication.
    * failed-req - The request was not made because of unknown reason.

=cut

sub new {
    my ($proto, @opts) = @_;
    my $class = ref $proto || $proto;

    my $fields;
    if (@opts % 2 == 0) {   # also catches calls w/o args
        $fields = { @opts };
    }
    elsif (ref $opts[0] eq 'HASH') {
        $fields = $opts[0];
    }
    else {
        croak "Incorrect arguments to new(). Pass either a hashref or a list of pairs.\n";
    }

    my $self = bless {}, $class;
    @{$self}{qw/login remotekey/} = @{$fields}{qw/login remotekey/};
    $self->return_feeds_as($fields->{return_feeds_as} || 'structure');

    return $self;
}

=head2 login([$login])

Read/Write accessor for login name. You can either get current login
or set it if you'd like to do it after calling C<new()>.

=head2 remotekey([$remotekey])

Read/Write accessor for remotekey. You can either get current remotekey
or set it if you'd like to do it after calling C<new()>.

Remotekey is a special password valid only for use via API calls.
A user can get his remotekey here: L<http://friendfeed.com/remotekey>

=cut

sub login {
    my ($self, $login) = @_;

    if ($login) {
        $self->{login} = $login;
    }

    return $self->{login};
}

sub remotekey {
    my ($self, $remotekey) = @_;

    if ($remotekey) {
        $self->{remotekey} = $remotekey;
    }

    return $self->{remotekey};
}

sub ua {
    my ($self, $ua) = @_;

    if ($ua) {
        $self->{ua} = $ua;
    }

    return $self->{ua};
}

sub _connect {
    my $self = shift;

    unless ($self->ua) {
        $self->ua(new LWP::UserAgent)
            or die;
    }
}

sub _has_auth {
    my $self = shift;

    return $self->login && $self->remotekey;
}

=head2 validate

Validates the current combination of login and remotekey.

=cut

sub validate {
    my $self = shift;
    $self->_http_req('GET', 'validate', 'need auth');
}

sub _api_url {
    my $self = shift;
    my $uri = shift;

    return $API_ENTRYPOINT . $uri;
}

sub _http_req {
    my ($self, $method, $uri, $needauth, @args) = @_;

    # all posts should be authenticated
    if ($needauth && !$self->_has_auth) {
        $self->last_error('need-auth');
        return;
    }

    $self->_connect();

    my ($needs_parsing, $format) = ($self->return_feeds_as eq 'structure', $self->return_feeds_as);
    $format = 'json' if $needs_parsing;

    my $req;
    if ($method eq 'GET') {
        my $get_uri = URI->new($self->_api_url($uri));
        $get_uri->query_form(format => $format) unless $format eq 'json';
        $get_uri->query_form(@args) if @args;

        $req = GET $get_uri->as_string;
    }
    else { # $method eq 'POST'
        my $post_uri = URI->new($self->_api_url($uri));
        $post_uri->query_form(format => $format) unless $format eq 'json';
        $req = POST $post_uri,
            @args;
    }

    if ($self->_has_auth) {
        $req->header(Authorization => 'Basic ' . encode_base64($self->login . ':' . $self->remotekey, q{}));
    }

    if ($Last_Http_Response = $self->ua->request($req)) {
        unless ($Last_Http_Response->is_success) {
            require JSON;       # should die if absent
            JSON->VERSION(2.0); # we need newer JSON
            # do some JSON magic
            $self->last_error(
                JSON::from_json($Last_Http_Response->content, { utf8 => 1})->{errorCode}
            );
            return;
        }
    }
    else {
        $self->last_error('failed-req');
        return;
    }

    if ($needs_parsing) {
        require JSON;       # should die if absent
        JSON->VERSION(2.0); # we need newer JSON
        # do some JSON magic
        return JSON::from_json($Last_Http_Response->content, { utf8 => 1});
    }
    else {
        return $Last_Http_Response->content;
    }
}

sub _fetch_feed {
    my $self = shift;
    my $uri = shift;

    $self->_http_req('GET', $uri, undef, @_);
}

sub _post {
    my $self = shift;
    my $uri = shift;

    $self->_http_req('POST', $uri, 'need auth', @_);
}

=head2 list_services

Returns the list of all services supported by FriendFeed.

The returned JSON has the format:

    * services[]
          o url - the official URL of the service, e.g., http://picasaweb.google.com/
          o icon - the URL of the favicon for this service
          o id - the service's FriendFeed ID, e.g., "picasa"
          o name - the service's official name, e.g., "Picasa Web Albums"

=cut

sub list_services {
    my $self = shift;

    $self->_fetch_feed('services', @_);
}

=head1 FEED FUNCTIONS

A number of methods fetch arrays of data or "feeds" from FriendFeed.
All feeds are available in two different formats: JSON and XML.

Net::FriendFeed adds one additional format called C<structure> which
means the feeds will be fetched as C<JSON> and then deserialized into
Perl structures using JSON.pm module. The format C<structure> is set by
default.

The feeds have the following structure (JSON-like notation is used):

    * entries[]
          o id - the FriendFeed entry UUID, used to add comments/likes to the entry
          o title
          o link
          o published
          o updated
          o hidden - if true, this entry should be hidden based on the user's preferences
          o anonymous - if true, user will be present but should not be shown 
          o user{} - the user who shared this entry
                + id - the user's FriendFeed UUID
                + name - the user's full name
                + nickname - the user's FriendFeed nickname, used in FriendFeed URLs
                + profileUrl - the user's profile URL on FriendFeed
          o service{} - the service from which the entry came
                + id - the service's FriendFeed ID, e.g., "picasa"
                + name - the service's official name, e.g., "Picasa Web Albums"
                + iconUrl - the URL of the favicon for this service
                + profileUrl - the user's profile URL on this service
          o comments[]
                + date
                + id - the UUID of the comment
                + user{} - same structure as the user{} structure above
                + body - the textual body of the comment
                o via{}? - present if this comment came from an API client
                    + name - the name of the API client, e.g., "fftogo"
                    + url - the official URL of the API client, e.g., http://www.fftogo.com
          o likes[]
                + date
                + user{} - same structure as the user{} structure above
          o media[] - the videos/images associated with the entry
                + title? - the title of the media file
                + player? - the player for this media file (e.g., the YouTube.com URL with the embedded video)
                + thumbnails[] - the thumbnails for this media file
                      # url
                      # width
                      # height
                + content[] - the different versions of the media file
                      # url
                      # type - the MIME type of the media file
                      # width
                      # height
          o via{}? - present if this entry came from an API client
                + name - the name of the API client, e.g., "Alert Thingy"
                + url - the official URL of the API client, e.g., http://www.alertthingy.com/
          o room{}? - if the entry is in a room, the room the entry is in

                + id - the room's FriendFeed UUID
                + name - the room's display name
                + nickname - the room's FriendFeed nickname, used in FriendFeed URLs
                + url - the room's URL on FriendFeed

The simple XML format has the same structure as the JSON.

Dates in JSON are in RFC 3339 format in UTC. You can parse them with the strptime string "%Y-%m-%dT%H:%M:%SZ".

All feed-fetching methods support additional parameters:

=over

=item service

only return entries from the service with the given ID, e.g., service=twitter

=item start

return entries starting with the given index, e.g., start=30

=item num

return num entries starting from start, e.g., num=10 

=back

They can be passed as key => value pairs after all the other arguments.

    $frf->fetch_user_feed('kkapp', num => 50, service => 'twitter');

=cut

=head2 return_feeds_as($type)

Gets or sets the type of return feeds.

This can be one of C<qw/structure xml json/> and defaults to
C<'structure'> which is a parsed Perl data structure. Other types are
string scalars.

=cut

sub return_feeds_as {
    my ($self, $format) = @_;

    if ($format) {
        ($format = lc($format)) =~ /^(?:json|structure|xml)\z/
            or croak "[$format] not supported. Use JSON, XML or structure.\n";
        $self->{return_feeds_as} = $format;
    }

    return $self->{return_feeds_as};
}

=head2 fetch_public_feed

Fetches the most recent 30 public entries published to FriendFeed.

=cut

sub fetch_public_feed {
    my $self = shift;

    $self->_fetch_feed('feed/public', @_);
}

=head2 fetch_user_feed($nickname)

Fetches the most recent entries from a user feed.
If the user has a private feed, authentication is required.

=cut

sub fetch_user_feed {
    my $self = shift;
    my $nickname = shift;

    $self->_fetch_feed('feed/user/' . uri_escape($nickname), @_);
}

=head2 fetch_user_comments_feed($nickname)

Returns the most recent entries the user has commented on, ordered by the date of that user's comments. 

=cut

sub fetch_user_comments_feed {
    my $self = shift;
    my $nickname = shift;

    $self->_fetch_feed('feed/user/' . uri_escape($nickname) . '/comments', @_);
}

=head2 fetch_user_likes_feed($nickname)

Returns the most recent entries the user has "liked," ordered by the date of that user's "likes".

=cut

sub fetch_user_likes_feed {
    my $self = shift;
    my $nickname = shift;

    $self->_fetch_feed('feed/user/' . uri_escape($nickname) . '/likes', @_);
}

=head2 fetch_user_discussion_feed($nickname)

Returns the most recent entries the user has commented on or "liked".

=cut

sub fetch_user_discussion_feed {
    my $self = shift;
    my $nickname = shift;

    $self->_fetch_feed('feed/user/' . uri_escape($nickname) . '/discussion', @_);
}

=head2 fetch_user_friends_feed($nickname)

Fetch a users "friends" feed.  This feed contains entries
from the user and her friends.  No private feeds will be included
unless you are authenticated and have access to that feed.

=cut

sub fetch_user_friends_feed {
    my $self = shift;
    my $nickname = shift;

    $self->_fetch_feed('feed/user/' . uri_escape($nickname) . '/friends', @_);
}

=head2 fetch_multi_user_feed(@nicknames)

Returns the most recent entries from a list of users, specified by nickname:

If more than one nickname is specified, the feed most recent entries
from all of the given users. If any one of the users has a private
feed, authentication is required.

User nicknames may also be passed as an arrayref.

    $frf->fetch_multi_user_feed(qw/kkapp mihun/);

=cut

sub fetch_multi_user_feed {
    my $self = shift;
    my @nicknames = @_;

    ref $nicknames[0] eq 'ARRAY'
        and @nicknames = @{$nicknames[0]};

    $self->_fetch_feed('feed/user', nickname => join(',', @nicknames), @_);
}

=head2 fetch_room_feed($room)

Returns the most recent entries in the room with the given nickname.

If the room is private, authentication is required.

=cut

sub fetch_room_feed {
    my $self = shift;
    my $room = shift;

    $self->_fetch_feed('feed/room/' . uri_escape($room), @_);
}

=head2 fetch_home_feed

Returns the entries the authenticated user would see on their FriendFeed homepage - all of their subscriptions and friend-of-a-friend entries.

Authentication is always required.

=cut

sub fetch_home_feed {
    my $self = shift;

    $self->_has_auth and
        $self->_fetch_feed('feed/home', @_);
}

=head2 fetch_entry($uuid[, @uuids])

Fetches a single or a list of entries by UUIDs. Needs authentication to read
private entries.

You can request up to 100 entries on each call. The entries you don't
have permission to read will be filtered out from the result feed.

=cut

sub fetch_entry {
    my $self = shift;
    my @entry_ids = @_;

    if (@entry_ids == 1) {
        $self->_fetch_feed('feed/entry/' . uri_escape($entry_ids[0]));
    }
    else {
        $self->_fetch_feed('feed/entry', entry_id =>
            Encode::encode('UTF-8', join(',', @entry_ids)));
    }
}

=head2 search($query)

Executes a search over the entries in FriendFeed. If the request is
authenticated, the default scope is over all of the entries in the
authenticated user's Friends Feed. If the request is not
authenticated, the default scope is over all public entries.

    $frf->search('rambler service:twitter');

The query syntax is the same syntax as http://friendfeed.com/search/advanced. The query operators are:

=over

=item who:

restricts the search to a specific user, e.g., who:bret

=item service:

restricts the search to a specific service ID, e.g., service:twitter 

=back

=cut

sub search {
    my $self = shift;
    my $q = shift;

    $self->_fetch_feed('feed/search', q => Encode::encode('UTF-8', $q), @_);
}

=head1 PUBLISHING FUNCTIONS

You can perform test calls from a web browser using the HTTP Basic
Authentication built into your browser at
L<http://friendfeed.com/static/html/apitest.html>.

Requests to FriendFeed are rate limited, which, e.g., limits the
number and size of thumbnails you can upload in a day. Normal uses
should fall well within our rate limits. If you encounter HTTP 403
errors because of rate limits, and you think the limit is erroneous,
please let us know in the developer forum.

=cut

=head2 publish($message) OR publish(named params)

Post a message with a title, images, audios and other possible options.
Requires authentication.

All non-ASCII input data should be clean Perl Unicode (that is, decoded from
any encoding). FriendFeed API is strictly UTF-8 so we unconditionally
encode strings into UTF-8 via Encode::encode('UTF-8', $data) call.

In its non-trivial (more than 1 argument) this method uses named parameters.
A call looks like this:

    $frf->publish(
        message => 'Message test',
        link    => 'http://link.example.com,
        images  => [ @images ],
        audios  => [ @audios ],
        room    => 'Room 1',
        via     => 'Perl!',
        comment => 'Hi there',
    );

The parameters are:

=over

=item message

Mandatory title of the posted item.

=item link

URL to refer to. May be absent.

=item comment

Automatically add first comment to the item.

=item images

This one is an arrayref of image items. Each image item is either an image PURL (path-or-URL) or a
pair (taken as arrayrefs of two elements) of PURL => URL. PURL in the
pair points to the image and URL is used as a href to follow when the
user clicks on this very image. URL defaults to the main link.

Each PURL may be either an (http|https|ftp) URL or a PATH to a local
file in which case that file gets uploaded directly to FriendFeed.

=item audios

This one is an arrayref of audio items. Each audio item is either an audio URL or a
pair (taken as arrayrefs of two elements) of URL => title. URL in the
pair points to the audio and title is shown near the audio player on
FriendFeed pages.

FriendFeed supports only MP3 audios.

=item room

This is a room nickname to which the post should be published.

=item via

This is an identifier of your software. It's ignored unless you
register it with FriendFeed administration.

=back

=cut

sub publish {
    my $self = shift;
    my %args = @_ < 2 ? ( message => $_[0] ) : @_;

    my @args = ();

    push @args, title => Encode::encode('UTF-8', $args{message});
    push @args, 'link' => $args{link} if defined $args{link};
    push @args, comment => Encode::encode('UTF-8', $args{comment}) if defined $args{comment};
    push @args, room => $args{room} if defined $args{room};
    push @args, via => $args{via} if defined $args{via};

    my $multipart;

    my $imgs = $args{images};
    if ($imgs && ref $imgs eq 'ARRAY') {
        foreach (0 .. $#$imgs) {
            if (ref $imgs->[$_]) { # image AND link

                if ($imgs->[$_]->[0] =~ m{^(?:http|https|ftp)://}) { # remote image
                    push @args, ("image${_}_url" => $imgs->[$_]->[0], "image${_}_link" => $imgs->[$_]->[1]);
                }
                else {
                    $multipart = 1;
                    my $filename = (File::Spec->splitpath($imgs->[$_]->[0]))[2]; # kinda basename
                    push @args, ("image${_}" => [$imgs->[$_]->[0], $filename], "${filename}_link" => $imgs->[$_]->[1]);
                }
            }
            else {
                if ($imgs->[$_] =~ m{^(?:http|https|ftp)://}) { # remote image
                    push @args, ("image${_}_url" => $imgs->[$_]);
                }
                else {
                    $multipart = 1;
                    push @args, ("image${_}" => [$imgs->[$_]]);
                }
            }
        }
    }

    my $audios = $args{audios};
    if ($audios && ref $audios eq 'ARRAY') {
        foreach (0 .. $#$audios) {
            if (ref $audios->[$_]) { # mp3 AND title
                push @args, ("audio${_}_url" => $audios->[$_]->[0], "audio${_}_title" => Encode::encode('UTF-8', $audios->[$_]->[1]));
            }
            else {
                push @args, ("audio${_}_url" => $audios->[$_]);
            }
        }
    }

    $self->_post('share', Content => \@args,
        $multipart ? (Content_Type => 'form-data') : ());
}

=head2 publish_link($title, $link, $comment, [@images, [$imgN, $linkN]], $room, $via)

I<This method is obsolete, use C<publish>>.

Share a link with a title, images and other possible options.
Requires authentication.

All non-ASCII input data should be clean Perl Unicode (that is, decoded from
any encoding). FriendFeed API is strictly UTF-8 so we unconditionally
encode strings into UTF-8 via Encode::encode('UTF-8', $data) call.

Full signature looks like: 
    $frf->publish_link($title, $link, $comment, [@images, [$imgN, $linkN]], $room, $via)

=over

=item $title

Mandatory title of the shared item.

=item $link

URL to refer to. If absent, the shared link reduces to text.

=item $comment

Automatically add first comment to the item.

=item $images

This one is an arrayref of image items. Each image item is either an image PURL or a
pair (taken as arrayrefs of two elements) of PURL => URL. PURL in the
pair points to the image and URL is used as a href to follow when the
user clicks on this very image. URL defaults to the main $link.

Each PURL may be either an (http|https|ftp) URL or a PATH to a local
file in which case that file gets uploaded directly to FriendFeed.

=item $room

This is a room nickname to which the link should be published.

=item $via

This is an identifier of your software. It's ignored unless you
register it with FriendFeed administration.

=back

=cut

sub publish_link {
    my $self = shift;
    my ($msg, $link, $comment, $imgs, $room, $via) = @_;

    $self->publish(
        message     => $msg,
        link        => $link,
        comment     => $comment,
        images      => $imgs,
        room        => $room,
        via         => $via,
    );
}

=head2 publish_message($msg)

I<This method is obsolete, use C<publish>>.

Share a piece of text. The simplest form of FriendFeed sharing.
Requires authentication.

This is actually a special case of publish_link with only $title set.

=cut

sub publish_message {
    my $self = shift;
    my $msg = shift;

    $self->publish($msg);
}

=head2 delete_entry($entry_id)

Delete an entry. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry.

=back

=cut

sub delete_entry {
    my $self = shift;
    my $entry_id = shift;

    $self->_post('entry/delete', [entry => $entry_id]);
}

=head2 undelete_entry($entry_id)

Undelete a deleted entry. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry.

=back

=cut

sub undelete_entry {
    my $self = shift;
    my $entry_id = shift;

    $self->_post('entry/delete', [
        entry       => $entry_id,
        undelete    => 1,
    ]);
}

=head2 hide_entry($entry_id)

Hides an entry for current user. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry.

=back

=cut

sub hide_entry {
    my $self = shift;
    my $entry_id = shift;

    $self->_post('entry/hide', [entry => $entry_id]);
}

=head2 unhide_entry($entry_id)

Unhide a hidden entry. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry.

=back

=cut

sub unhide_entry {
    my $self = shift;
    my $entry_id = shift;

    $self->_post('entry/hide', [
        entry       => $entry_id,
        unhide    => 1,
    ]);
}

=head1 COMMENT AND LIKE FUNCTIONS

=head2 add_comment($entry_id, $body, $via)

Add a comment on a FriendFeed entry. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry to which this comment is attached.

=item $body

required - The textual body of the comment.

=item $via

This is an identifier of your software. It's ignored unless you
register it with FriendFeed administration.

=back

    $frf->add_comment('550e8400-e29b-41d4-a716-446655440000', 'Testing the FriendFeed API', 'Microsoft Word');

=cut

sub add_comment {
    my $self = shift;
    my ($entry_id, $comment_text, $via) = @_;

    $self->_post('comment', [entry => $entry_id, body => Encode::encode('UTF-8', $comment_text), defined $via ? (via => $via) : ()]);
}

=head2 edit_comment($entry_id, $body, $comment_id)

Edit an existing comment on a FriendFeed entry. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry to which this comment is attached.

=item $body

required - The textual body of the comment.

=item $comment_id

The FriendFeed UUID of the comment to edit. If not given, the request will create a new comment. 

=back

=cut

sub edit_comment {
    my $self = shift;
    my ($entry_id, $comment_text, $comment_id) = @_;

    $self->_post('comment', [
        entry   => $entry_id,
        comment => $comment_id,
        body    => Encode::encode('UTF-8', $comment_text),
    ]);
}

=head2 delete_comment($entry_id, $comment_id)

Delete an existing comment. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry to which this comment is attached.

=item $comment_id

required - The FriendFeed UUID of the comment to delete. 

=back

=cut

sub delete_comment {
    my $self = shift;
    my ($entry_id, $comment_id) = @_;

    $self->_post('comment/delete', [entry => $entry_id, comment => $comment_id]);
}

=head2 undelete_comment($entry_id, $comment_id)

Undelete a deleted comment. The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry to which this comment is attached.

=item $comment_id

required - The FriendFeed UUID of the comment to undelete. 

=back

=cut

sub undelete_comment {
    my $self = shift;
    my ($entry_id, $comment_id) = @_;

    $self->_post('comment/delete', [
        entry       => $entry_id,
        comment     => $comment_id,
        undelete    => 1,
    ]);
}

=head2 add_like($entry_id)

Add a "Like" to a FriendFeed entry for the authenticated user.

=over

=item $entry_id

required - The FriendFeed UUID of the entry to which this comment is attached

=back

    $frf->add_like("550e8400-e29b-41d4-a716-446655440000");

=cut

sub add_like {
    my $self = shift;
    my $entry_id = shift;

    $self->_post('like', [entry => $entry_id]);
}

=head2 delete_like($entry_id)

Delete an existing "Like". The arguments are:

=over

=item $entry_id

required - The FriendFeed UUID of the entry to which this comment is attached.

=back

=cut

sub delete_like {
    my $self = shift;
    my $entry_id = shift;

    $self->_post('like/delete', [entry => $entry_id]);
}

=head1 PROFILE FUNCTIONS

=head2 fetch_user_profile($nickname)

Returns list of all of the user's subscriptions (people) and services connected to their account.

The returned data has this structure:

    * id - the user's FriendFeed UUID
    * name - the user's full name
    * nickname - the user's FriendFeed nickname, used in FriendFeed URLs
    * profileUrl - the user's profile URL on FriendFeed
    * services[] - the services connected to the user's account
          o id - the service's FriendFeed ID, e.g., "picasa"
          o name - the service's official name, e.g., "Picasa Web Albums"
          o url - the official URL of the service, e.g., http://picasaweb.google.com/
          o iconUrl - the URL of the favicon for this service
          o profileUrl? - the user's profile URL on this service, if any
          o username? - the user's username for this service, if any 
    * subscriptions[] - the users this user is subscribed to
          o id
          o name
          o nickname
          o profileUrl 
    * rooms[] - the rooms this user is a member of
          o id - the room's FriendFeed UUID
          o name - the room's display name
          o nickname - the room's FriendFeed nickname, used in FriendFeed URLs
          o url - the room's URL on FriendFeed

=cut

sub fetch_user_profile {
    my $self = shift;
    my $nickname = shift;

    $self->_fetch_feed('user/' . uri_escape($nickname) . '/profile', @_);
}

=head2 fetch_user_profiles(@nicknames)

Returns profiles for multiple users. The returned structure has one
element C<profiles> which is an array of profile structures described
alongside C<fetch_user_profile> method. 

User nicknames may also be passed as an arrayref.

=cut

sub fetch_user_profiles {
    my $self = shift;
    my @nicknames = @_;

    ref $nicknames[0] eq 'ARRAY'
        and @nicknames = @{$nicknames[0]};

    $self->_fetch_feed('profiles', nickname => join(',', @nicknames), @_);
}

=head1 AUTHOR

Alex Kapranoff, C<< <kappa at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-friendfeed at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-FriendFeed>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::FriendFeed


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-FriendFeed>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-FriendFeed>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-FriendFeed>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-FriendFeed>

=back

=head1 ACKNOWLEDGEMENTS

Mark Carey prompted to implement C<via> for comments.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Alex Kapranoff.

This program is released under the following license: GPLv3

=cut

1; # End of Net::FriendFeed
