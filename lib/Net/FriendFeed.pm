package Net::FriendFeed;

use warnings;
use strict;

=head1 NAME

Net::FriendFeed - Perl interface to FriendFeed.com API

=cut

our $VERSION = '0.2';

#use JSON::Any;
use LWP::UserAgent;
use HTTP::Request::Common;
use MIME::Base64 qw/encode_base64/;

use base qw(Class::Accessor);
Net::FriendFeed->mk_accessors(qw/login remotekey ua return_feeds_as/);

our $Api_EntryPoint = 'http://friendfeed.com/api/';

=head1 SYNOPSIS

FriendFeed is a social feed agregator with a clean public REST-based
API. This package allows easy access to FriendFeed from Perl.

Methods are named in accordance with the official Python package.

    use Net::FriendFeed;

    my $frf = Net::FriendFeed->new();
    $frf->publish_message('Hello, world!');
    ...

=cut

=head1 FUNCTIONS

=head2 new

This is a constructor for FriendFeed object. It takes an optional
hashref parameter with auth credentials.

Example:
    my $frf = Net::FriendFeed->new({login => 'kkapp', remotekey => 'hfytr38'});

The remotekey is a kind of easily regeneratable password used
only in API functions. A user can get his remotekey here:
http://friendfeed.com/remotekey

Authentication is needed only to post or to read private feeds.

=cut

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;

    $fields = {} unless defined $fields;

    my $self = {%$fields};

    $self->{return_feeds_as} ||= 'structure';

    # make a copy of $fields.
    bless $self, $class;
}

sub _connect {
    my $self = shift;

    unless ($self->ua) {
        $self->ua(new LWP::UserAgent)
            or die;
    }
}

sub _need_auth {
    my $self = shift;

    return $self->login && $self->remotekey;
}

sub _api_url {
    my $self = shift;
    my $uri = shift;

    return $Api_EntryPoint . $uri;
}

sub _fetch_feed {
    my $self = shift;
    my $uri = shift;
    my @args = @_;

    $self->_connect();

    my ($needs_parsing, $format) = ($self->return_feeds_as eq 'structure', $self->return_feeds_as);
    $format = 'json' if $needs_parsing;

    my $get_uri = URI->new($self->_api_url($uri));
    $get_uri->query_form(format => $format);
    $get_uri->query_form(@args) if @args;

    my $req = GET $get_uri->as_string;

    if ($self->login && $self->remotekey) {
        $req->header(Authorization => 'Basic ' . encode_base64($self->login . ':' . $self->remotekey, q{}));
    }

    if ($needs_parsing) {
        my $rv = $self->ua->request($req);
        # do some JSON magic
        return 'JSON';
    }
    else {
        $self->ua->request($req);
    }
}

sub _post {
    my $self = shift;
    my $uri = shift;

    $self->_connect();

    my $req = POST
        $self->_api_url($uri),
        shift();

    if ($self->login && $self->remotekey) {
        $req->header(Authorization => 'Basic ' . encode_base64($self->login . ':' . $self->remotekey, q{}));
    }

    $self->ua->request($req);
}

=head1 Feeds

A number of methods fetch different feeds from FriendFeed.

The feeds have the following structure:

    * entries[]
          o id - the FriendFeed entry UUID, used to add comments/likes to the entry
          o title
          o link
          o published
          o updated
          o hidden - if true, this entry should be hidden based on the user's preferences
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

The simple XML format (output=xml) has the same structure as the JSON. The RSS and Atom formats use the standard RSS and Atom attributes for title, link, published, and updated, and include extension elements for all of the other meta-data.

Dates in JSON and dates in the FriendFeed extension elements in the Atom and RSS feeds are in RFC 3339 format in UTC. You can parse them with the strptime string "%Y-%m-%dT%H:%M:%SZ".
Filtering & Paging

=cut

=head2 return_feeds_as

Gets or sets the type of return feeds.

This can be one of qw/structure xml atom rss json/ and defaults to
'structure' which is a parsed Perl data structure. Other types are
string scalars.

=cut

=head2 fetch_public_feed

Fetches the most recent 30 public entries published to FriendFeed.

This feed and all the other feed-fetching methods support additional
parameters:

=over

=item service

only return entries from the service with the given ID, e.g., service=twitter

=item start

return entries starting with the given index, e.g., start=30

=item num

return num entries starting from start, e.g., num=10 

=back

=cut

sub fetch_public_feed {
    my $self = shift;

    $self->_fetch_feed('feed/public', @_);
}

=head2 fetch_user_feed

Fetches the most recent entries from a user feed.
If the user has a private feed, authentication is required.

=cut

sub fetch_user_feed {
    my $self = shift;
    my $user = shift;

    $self->_fetch_feed("feed/user/$user", @_);
}

=head2 fetch_user_comments_feed

Returns the most recent entries the user has commented on, ordered by the date of that user's comments. 

=cut

sub fetch_user_comments_feed {
    my $self = shift;
    my $user = shift;

    $self->_fetch_feed("feed/user/$user/comments", @_);
}

=head2 fetch_user_likes_feed

Returns the most recent entries the user has "liked," ordered by the date of that user's "likes".

=cut

sub fetch_user_likes_feed {
    my $self = shift;
    my $user = shift;

    $self->_fetch_feed("feed/user/$user/likes", @_);
}

=head2 fetch_user_discussion_feed

Returns the most recent entries the user has commented on or "liked".

=cut

sub fetch_user_discussion_feed {
    my $self = shift;
    my $user = shift;

    $self->_fetch_feed("feed/user/$user/discussion", @_);
}

=head2 fetch_multi_user_feed

Returns the most recent entries from a list of users, specified by nickname:

If more than one nickname is specified, the feed most recent entries
from all of the given users. If any one of the users has a private
feed, authentication is required.

User nicknames should be passed as an arrayref.

    $frf->fetch_multi_user_feed([qw/kkapp mihun/]);

=cut

sub fetch_multi_user_feed {
    my $self = shift;
    my $users = shift;

    $self->_fetch_feed("feed/user", nickname => join(',', @$users), @_);
}

=head2 fetch_home_feed

Returns the entries the authenticated user would see on their FriendFeed homepage - all of their subscriptions and friend-of-a-friend entries.

Authentication is always required.

=cut

sub fetch_home_feed {
    my $self = shift;
    my $user = shift;

    $self->_need_auth and
        $self->_fetch_feed("feed/home", @_);
}

=head2 search

Executes a search over the entries in FriendFeed. If the request is
authenticated, the default scope is over all of the entries in the
authenticated user's Friends Feed. If the request is not
authenticated, the default scope is over all public entries.

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

    $self->_fetch_feed("feed/search", q => Encode::encode('UTF-8', $q), @_);
}

=head1 Publishing To FriendFeed

All of the calls to publish information to FriendFeed are HTTP requests. You can perform test calls from a web browser using the HTTP Basic Authentication built into your browser at http://friendfeed.com/static/html/apitest.html.

Requests to FriendFeed are rate limited, which, e.g., limits the number and size of thumbnails you can upload in a day. Normal uses should fall well within our rate limits. If you encounter HTTP 403 errors because of rate limits, and you think the limit is erroneous, please let us know in the developer forum.
Create New Entries
/api/share - Publish Links or Messages

A POST request to /api/share will publish a new entry on the authenticated user's feed. The arguments are:

    * title - required - The text of the new entry.
    * link - The URL of the new entry. If it is not specified, the new entry will look like a quoted message. If specified, it will look like a link.
    * comment - If specified, the given text is posted as a comment under the new entry.
    * imageN_url, imageN_link - The thumbnail images for the entry, specified from a 0-based index. image0_url specifies the URL of the image, which will be resized to the maximum size of a thumbnail and stored on FriendFeed's servers. If image0_link is not given, the thumbnail will link to the main link URL. If it is specified, the thumbnail will link to the specified image0_link. 

Example usage with the FriendFeed Python library:

service = friendfeed.FriendFeed(nickname, remote_key)

# Publish a text message
service.publish_message("Testing the FriendFeed API")

# Publish a link
service.publish_link("Testing the FriendFeed API", "http://friendfeed.com/api/")

# Publish a link with thumbnail images
service.publish_link(
    title="Testing the FriendFeed API",
    link="http://friendfeed.com/api/",
    image_urls=[
        "http://friendfeed.com/static/images/jim-superman.jpg",
        "http://friendfeed.com/static/images/logo.png",
    ],
)

Example usage with curl:

curl -u "nickname:remotekey" -d "title=Testing+the+FriendFeed+API&link=http://friendfeed.com/" http://friendfeed.com/api/share

=cut

=head2 publish_link

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

=item $links

URL to refer to. If absent, the shared link reduces to text.

=item $comment

Automatically add 1st comment to the item.

=item $images

This one is an arrayref of either image URLs or pairs (taken as
arrayrefs of two elements) or URL1 => URL2. URL1 in the pair points to
the image and URL2 is used as a href to follow when the user clicks on
this very image. URL2 defaults to the main $link.

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

    my @args = ();

    push @args, title => Encode::encode('UTF-8', $msg);
    push @args, 'link' => $link if defined $link;
    push @args, comment => Encode::encode('UTF-8', $comment) if defined $comment;
    push @args, room => $room if defined $room;
    push @args, via => $via if defined $via;

    if ($imgs && ref $imgs eq 'ARRAY') {
        push @args, (
            ref $imgs->[$_]
            ? ("image${_}_url" => $imgs->[$_]->[0], "image${_}_link" => $imgs->[$_]->[1])
            : ("image${_}_url" => $imgs->[$_])
        ) foreach 0 .. $#$imgs;
    }

    $self->_need_auth and
        $self->_post('share', \@args);
}

=head2 publish_message

Share a piece of text. The simplest form of FriendFeed sharing.
Requires authentication.

This is actually a special case of publish_link with only $title set.

=cut

sub publish_message {
    my $self = shift;
    my $msg = shift;

    $self->publish_link($msg);
}

=head2 Upload Images with Entries

The /api/share method can also accept uploaded images encoded as multipart/form-data. This encoding is the standard used for file uploads within web browsers.

If any images are uploaded with the /api/share request, the original and the thumbnail are stored on FriendFeed's servers, and the thumbnail is displayed with the entry.

By default, the thumbnails will link to the destination link for the entry. If you want each uploaded image to link somewhere else, you can specify the link in the IMAGENAME_link argument. For example, if your uploaded image is POST argument file0, you can specify the link for that thumbnail as file0_link.
Comment and Like Entries
/api/comment - Add or Edit Comments

A POST request to /feed/comment will add a comment or edit an existing comment on a FriendFeed entry. The arguments are:

    * entry - required - The FriendFeed UUID of the entry to which this comment is attached.
    * body - required - The textual body of the comment.
    * comment - If given, the FriendFeed UUID of the comment to edit. If not given, the request will create a new comment. 

Example usage from the Python library:

service = friendfeed.FriendFeed(nickname, remote_key)
service.add_comment(
    entry="550e8400-e29b-41d4-a716-446655440000",
    body="Testing the FriendFeed API",
)

Example usage with curl:

curl -u "nickname:remotekey" -d "entry=550e8400-e29b-41d4-a716-446655440000&body=Testing+the+FriendFeed+API" http://friendfeed.com/api/comment

/api/comment/delete - Delete a Comment

A POST request to /feed/comment/delete will delete an existing comment. The arguments are:

    * entry - required - The FriendFeed UUID of the entry to which this comment is attached.
    * comment - required - The FriendFeed UUID of the comment to delete. 

/api/like - "Like" an Entry

A POST request to /feed/like will add a "Like" to a FriendFeed entry for the authenticated user.

    * entry - required - The FriendFeed UUID of the entry to which this comment is attached 

Example usage from the Python library:

service = friendfeed.FriendFeed(nickname, remote_key)
service.add_like("550e8400-e29b-41d4-a716-446655440000")

Example usage with curl:

curl -u "nickname:remotekey" -d "entry=550e8400-e29b-41d4-a716-446655440000" http://friendfeed.com/api/like

/api/like/delete - Delete a "Like"

A POST request to /feed/like/delete will delete an existing "Like." The arguments are:

    * entry - required - The FriendFeed UUID of the entry to which this comment is attached. 

Get User Profile Information
/api/user/USERNAME/profile - Get services and subscriptions

Returns list of all of the user's subscriptions (people) and services connected to their account:

http://friendfeed.com/api/user/bret/profile

The returned JSON has the form:

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

    * subscriptions[] - the user's this user is subscribed to
          o id
          o name
          o nickname
          o profileUrl 

=cut

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


=head1 COPYRIGHT & LICENSE

Copyright 2008 Alex Kapranoff, all rights reserved.

This program is released under the following license: GPLv3


=cut

1; # End of Net::FriendFeed
