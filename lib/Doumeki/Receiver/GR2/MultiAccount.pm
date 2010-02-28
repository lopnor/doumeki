package Doumeki::Receiver::GR2::MultiAccount;
use Any::Moose;

with qw(
    Doumeki::Receiver::Base
    Doumeki::Receiver::GR2::Base
);

sub login {
    my ($self, $req, $res, $param) = @_;

    if ($self->call_trigger('login', $req)) {
        $req->session->set('logined'=>1);
        return $self->success($req, $res, {
                gr2 => { status_text => 'Login successful' }
            });
    }
    return $self->error($req, $res, {
        gr2  => {
            status => $Doumeki::Receiver::GR2::Base::LOGIN_MISSING,
            status_text => "Auth error",
        },
    });
}

1;
