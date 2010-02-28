package Doumeki::Receiver::GR2;
use Any::Moose;
use Readonly;

with qw(
    Doumeki::Receiver::Base
    Doumeki::Receiver::GR2::Base
);

has 'user' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
   );

has 'password' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
   );

__PACKAGE__->meta->make_immutable;

no Any::Moose;

Readonly my $LOGIN_MISSING              => 202;

sub login {
    my($self, $req, $res, $param) = @_;

    if (   $param->{uname}    eq $self->user
        && $param->{password} eq $self->password) {

        $req->session->set('logined'=>1);

        if ($self->call_trigger('login', $req)) {
            return $self->success($req, $res, {
                gr2 => { status_text => 'Login successful' }
               });
        }
    }

    return $self->error($req, $res, {
        gr2  => {
            status => $Doumeki::Receiver::GR2::Base::LOGIN_MISSING,
            status_text => "Auth error",
        },
    });
}

1;
