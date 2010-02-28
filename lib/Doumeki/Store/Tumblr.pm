package Doumeki::Store::Tumblr;
use Any::Moose;
use Carp;
use WWW::Tumblr;
use WWW::Mechanize;
use Web::Scraper;
use HTTP::Request::Common ();
use URI::Escape;

with 'Doumeki::Store::Base';

sub login {
    my ($self, $receiver, $req) = @_;
    Doumeki::Log->log(debug => '>>'.(caller(0))[3]);
    if (
        my ($email, $channel) = (
            $req->param('g2_form[uname]') =~ m{^(.+)\@tumblr(?:/(.+))?$}
        )
    ) {
        $channel ||= '';
        Doumeki::Log->log(debug => 'email:'. $email);
        Doumeki::Log->log(debug => 'channel:'. $channel);
        my $password = $req->param('g2_form[password]');
        my $t = WWW::Tumblr->new( 
            map( {uri_escape($_)}
                email => $email, 
                password => $password,
            )
        );
        if ( my $res = $t->authenticate ) {
            Doumeki::Log->log(debug => 'login ok');
            $req->session->set(tumblr => {
                    email => $email,
                    password => $password,
                    channel => $channel,
                }
            );
        } else {
            Doumeki::Log->log(error => $t->errstr);
        }
    }
    1;
}

sub add_item {
    my ($self, $receiver, $tempname, $filename, $req) = @_;
    Doumeki::Log->log(debug => '>>'.(caller(0))[3]);
    my $sess = $req->session->get('tumblr') or return 1;
    Doumeki::Log->log(debug => 'email: '. $sess->{email});
    Doumeki::Log->log(debug => 'channel: '. $sess->{channel});
    my $mech = WWW::Mechanize->new;
    $mech->post(
        'http://www.tumblr.com/login',
        {
            email => $sess->{email}, 
            password => $sess->{password},
        }
    );
    if ($mech->uri ne 'http://www.tumblr.com/dashboard') {
        Doumeki::Log->log(error => 'login failed');
        return 1;
    }
    $mech->get('http://www.tumblr.com/new/photo');
    $mech->form_id('edit_post');
    $mech->select('channel_id' => $sess->{channel}) if $sess->{channel};
    $mech->current_form->find_input('images[o1]')->file($tempname);
    $mech->click_button(number => 1);
    if (
        my $error = scraper {
            process '#errors', 'error', 'TEXT';
            result 'error';
        }->scrape(\($mech->response->decoded_content))
    ) {
        Doumeki::Log->log(error => $error);
    }
    1;
}

sub new_album {1}

1;
