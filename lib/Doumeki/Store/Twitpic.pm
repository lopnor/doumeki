package Doumeki::Store::Twitpic;
use Any::Moose;

use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;

with qw(Doumeki::Store::Base);

__PACKAGE__->meta->make_immutable;

no Any::Moose;

sub login {
    my ($self, $receiver, $req) = @_;
    Doumeki::Log->log(debug => '>>'.(caller(0))[3]);
    # implement me if you need
    if (
        my ($username) = ($req->param('g2_form[uname]') =~ m{^(.+)\@twitpic$})
    ) {
        Doumeki::Log->log(debug => 'username:'. $username);
        my $password = $req->param('g2_form[password]');
        my $ua = LWP::UserAgent->new;
        $ua->credentials('api.twitter.com:80','Twitter API',$username, $password);
        my $res = $ua->get(
            'http://api.twitter.com/1/account/verify_credentials.json'
        );
        if ($res->is_success) {
            Doumeki::Log->log(debug => 'login ok');
            $req->session->set(
                twitpic => {
                    username => $username,
                    password => $password,
                }
            );
        } else {
            Doumeki::Log->log(error => $res->as_string);
        }
    }
        
    return 1;
}

sub add_item {
    my($self, $receiver, $tempname, $filename, $req) = @_;
    Doumeki::Log->log(debug => '>>'.(caller(0))[3]);
    # implement me if you need
    my $sess = $req->session->get('twitpic') or return 1;
    Doumeki::Log->log(debug => 'username: ' . $sess->{username});
    my $res = LWP::UserAgent->new->request(
        POST 'http://twitpic.com/api/uploadAndPost',
        Content_Type => 'multipart/form-data',
        Content => [
            username => $sess->{username},
            password => $sess->{password},
            media => [ $tempname ],
            message => '#eyefi',
        ]
    );
    if ($res->is_success) {
        my ($url) = ($res->content =~ m{<mediaurl>(.+)</mediaurl>});
        Doumeki::Log->log(info => 'uploaded: '.$url);
    } else {
        Doumeki::Log->log(error => $res->content);
    }
    return 1;
}

sub new_album {
    Doumeki::Log->log(debug => '>>'.(caller(0))[3]);
    # implement me if you need
    return 1;
}

1;
__END__

=head1 NAME

Doumeki::Store::Skeleton - skeleton class for your new Store

=head1 SYNOPSIS

  store:
    Local:
      foo: blah

=head1 ATTRIBUTES

=over 4

=item foo: Str

...

=back

=head1 AUTHOR

HIROSE Masaaki E<lt>hirose31 _at_ gmail.comE<gt>

=head1 SEE ALSO

L<Doumeki>

=cut
