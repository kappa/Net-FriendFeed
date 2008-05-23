package Net::FriendFeed;

use warnings;
use strict;

=head1 NAME

Net::FriendFeed - Perl interface to FriendFeed.com API

=cut

our $VERSION = '0.1';

#use JSON::Any;
use LWP::UserAgent;
use HTTP::Request::Common;
use MIME::Base64 qw/encode_base64/;

use base qw(Class::Accessor);
Net::FriendFeed->mk_accessors(qw/login remotekey ua/);

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

sub _post {
    my $self = shift;
    my $uri = shift;

    $self->_connect();

    my $req = POST
        $self->_api_url($uri),
#        [via => 'Net::FriendFeed', @{shift()}];
        shift();

    if ($self->login && $self->remotekey) {
        $req->header(Authorization => 'Basic ' . encode_base64($self->login . ':' . $self->remotekey, q{}));
    }

    $self->ua->request($req);
}

=head1 FF API doc

All requests to the FriendFeed API are simple HTTP GET and POST requests. For example, you can fetch the JSON version of the most recent 30 public entries published to FriendFeed by fetching http://friendfeed.com/api/feed/public.

All of the API requests that output feeds are available in four formats: JSON, a simple form of XML, RSS 2.0, and Atom 1.0. JSON is the default output format. To request a different output format, simply add an format= argument to the URL:

    * http://friendfeed.com/api/feed/public?format=json
    * http://friendfeed.com/api/feed/public?format=xml
    * http://friendfeed.com/api/feed/public?format=rss
    * http://friendfeed.com/api/feed/public?format=atom 

The other API requests, like posting a new comment on an entry, only support the JSON and XML output formats since they do not output feed-oriented data.
Authentication

If you are publishing data to FriendFeed or if you are requesting the feed that includes data from a user with a private feed, your HTTP requests must be authenticated.

All FriendFeed users have a Remote Key to provide third party applications access to their FriendFeed. A FriendFeed Remote Key is just like a password, except that it is only used for third party applications, so it only provides access to the functionality defined by the API. Users can easily reset it if a third party application abuses the API.

All requests that require authentication use HTTP Basic Authentication. The username should be the user's nickname, and the password should be the user's Remote Key. You can direct user's to http://friendfeed.com/remotekey to get their remote key if they have not memorized it. See the FriendFeed API Application Guidelines for a complete set of recommendations of how to present authentication in your application.

The Python and PHP libraries available at http://code.google.com/p/friendfeed-api/ implement authentication for all methods that require it.

Note: We are currently exploring adding OAuth support as well. If you are interested in this support, let us know in the FriendFeed developer forum.
JSON Callbacks

The JSON output format supports an additional argument callback= that wraps the JSON output in a function call to a function of your choice. This functionality is available to enable you to use the API with JavaScript within a web browser. For example, http://friendfeed.com/api/feed/public?callback=foo outputs:

foo({"entries":[...]})

Using JSON and callbacks, you can place the FriendFeed API request inside a <script> tag, and operate on the results with a function elsewhere in the JavaScript code on the page.

All authentication is ignored if the callback= argument is given, so JSON callbacks only work with public feeds.
Reading FriendFeed Feeds
Overview
Feed Formats

The JSON form of the feeds has the following structure:

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

All of the feed methods below support the following additional arguments:

    * service - only return entries from the service with the given ID, e.g., service=twitter
    * start - return entries starting with the given index, e.g., start=30
    * num - return num entries starting from start, e.g., num=10 

Methods
/api/feed/public - Fetch all Public Entries

Returns the most recent public entries on FriendFeed:

http://friendfeed.com/api/feed/public

Using the FriendFeed Python library:

service = friendfeed.FriendFeed()
feed = service.fetch_public_feed()
for entry in feed["entries"]:
    print entry["title"]

/api/feed/user/NICKNAME - Fetch Entries from a User

Returns the most recent entries from the user with the given nickname:

http://friendfeed.com/api/feed/user/bret

If the user has a private feed, authentication is required.

Using the FriendFeed Python library:

service = friendfeed.FriendFeed()
feed = service.fetch_user_feed("bret")
for entry in feed["entries"]:
    print entry["title"]

/api/feed/user/NICKNAME/comments - Fetch Entries a User Has Commented On

Returns the most recent entries the user has commented on, ordered by the date of that user's comments:

http://friendfeed.com/api/feed/user/bret/comments

If the user has a private feed, authentication is required.
/api/feed/user/NICKNAME/likes - Fetch Entries a User Has "Liked"

Returns the most recent entries the user has "liked," ordered by the date of that user's "likes":

http://friendfeed.com/api/feed/user/bret/likes

If the user has a private feed, authentication is required.
/api/feed/user/NICKNAME/discussion - Fetch Entries a User Has Commented On or "Liked"

Returns the most recent entries the user has commented on or "liked":

http://friendfeed.com/api/feed/user/bret/discussion

If the user has a private feed, authentication is required.
/api/feed/user - Fetch Entries from Multiple Users

Returns the most recent entries from a list of users, specified by nickname:

http://friendfeed.com/api/feed/user?nickname=bret,paul,jim

If more than one nickname is specified, the feed most recent entries from all of the given users. If any one of the users has a private feed, authentication is required.

Using the FriendFeed Python library:

service = friendfeed.FriendFeed()
feed = service.fetch_multi_user_feed(["bret", "jim", "paul"])
for entry in feed["entries"]:
    print entry["title"]

/api/feed/home - Fetch the Friends Feed

Returns the entries the authenticated user would see on their FriendFeed homepage - all of their subscriptions and friend-of-a-friend entries:

http://friendfeed.com/api/feed/home

Authentication is always required.

Using the FriendFeed Python library:

service = friendfeed.FriendFeed(nickname, remote_key)
feed = service.fetch_home_feed()
for entry in feed["entries"]:
    print entry["title"]

/api/feed/search - Search

Executes a search over the entries in FriendFeed. If the request is authenticated, the default scope is over all of the entries in the authenticated user's Friends Feed. If the request is not authenticated, the default scope is over all public entries.

http://friendfeed.com/api/feed/search?q=friendfeed

The query syntax is the same syntax as http://friendfeed.com/search/advanced. The query operators are:

    * who: -restricts the search to a specific user, e.g., who:bret
    * service: restricts the search to a specific service ID, e.g., service:twitter 

Using the FriendFeed Python library:

service = friendfeed.FriendFeed()
feed = service.search("who:bret friendfeed")
for entry in feed["entries"]:
    print entry["title"]

=cut

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

Share a link with a title and images.

=cut.

sub publish_link {
    my $self = shift;
    my ($msg, $link, $imgs) = @_;

    my @args = ();

    push @args, title => $msg;
    push @args, 'link' => $link if defined $link;

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
