package Doumeki::Receiver::GR2::Base;
use Any::Moose '::Role';
use Readonly;

Readonly my $GR_STAT_SUCCESS            => 0;
Readonly my $UNKNOWN_CMD                => 301;
Readonly my $PASSWD_WRONG               => 201;
Readonly my $LOGIN_MISSING              => 202;
Readonly my $NO_ADD_PERMISSION          => 401;
Readonly my $NO_FILENAME                => 402;
Readonly my $UPLOAD_PHOTO_FAIL          => 403;
Readonly my $NO_WRITE_PERMISSION        => 404;
Readonly my $NO_VIEW_PERMISSION         => 405;
Readonly my $NO_CREATE_ALBUM_PERMISSION => 501;
Readonly my $CREATE_ALBUM_FAILED        => 502;
Readonly my $TRUE                       => 'true';
Readonly my $FALSE                      => 'false';
Readonly my $SERVER_VERSION             => '2.11';

Readonly my $COMMAND_TABLE => {
    'login'              => 'login',
    'fetch-albums-prune' => 'fetch_albums',
    'fetch-albums'       => 'fetch_albums',
    'add-item'           => 'add_item',
    'new-album'          => 'new_album',
};

sub handle_request {
    my($self, $req) = @_;

    my $path = $req->path;
    my $res  = HTTP::Engine::Response->new;

    if ($req->method ne 'POST') {
        return $self->error($req, $res, {
            http => { 405 => "Method Not Allowed" },
            log  => $req->method." ".$path,
        });
    }

    my %param;
    if ($req->param('g2_controller') eq 'remote:GalleryRemote') {
        for my $key( $req->param ) {
            if ( $key =~ m{g2_form\[([^\[\]]+)\]} ) {
                $param{$1} = $req->param( $key );
            }
        }
    } else {
        return $self->error($req, $res, {
            http => { 400 => "Bad Request" },
            log  => $req->param("g2_controller"),
        });
    }
    if (! $param{cmd} && $req->user_agent =~ m{Gallery/.+Darwin}) {
        $param{cmd} = "add-item";
    }

    Doumeki::Log->log(debug => "param: ".YAML::XS::Dump(\%param));
    if (! exists $COMMAND_TABLE->{ $param{cmd} }) {
        return $self->error($req, $res, {
            http => { 200 => "Unknown Command" },
            gr2  => {
                status => $UNKNOWN_CMD,
                status_text => "Unknown Command",
            },
            log  => $req->param("g2_controller"),
        });
    }

    eval {
        my $method = $COMMAND_TABLE->{ $param{cmd} };

        if ($method ne 'login' && not $req->session->get("logined")) {
            $self->error($req, $res, {
                http => { 200 => "Need Login" },
                gr2  => {
                    status => $LOGIN_MISSING,
                    status_text => "Need Login",
                },
            });
        } else {
            Doumeki::Log->log(debug => "dispatch to $method");
            $self->$method($req, $res, \%param);
        }
    };

    unless ($@) {
        return $res;
    } else {
        my %http_res;
        if ($@ && $@ =~ /Not found/) {
            %http_res = (404 => "Not Found");
        } elsif ($@ && $@ =~ /Forbidden/) {
            %http_res = (403 => "Forbidden");
        } elsif ($@) {
            %http_res = (500 => "Internal Server Error: $@");
            Doumeki::Log->log(error => $@);
        }
        return $self->error($req, $res, { http => \%http_res, });
    }
}

sub fetch_albums {
    my($self, $req, $res, $param) = @_;

    my $list = ['doumeki_dummy'];

    my @albums = map {
        +{
            name               => $_,
            title              => $_,
            'perms.add'        => $TRUE,
            'perms.write'      => $TRUE,
            'perms.del_item'   => $TRUE,
            'perms.create_sub' => $TRUE,
            'parent'           => 0,
        },
    } @{$list};

    $self->success($req, $res, {
        gr2 => {
            status_text     => 'Fetch albums successful',
            album           => \@albums,
            album_count     => scalar(@albums),
            can_create_root => 'yes',
        }
       });
}

sub add_item {
    my($self, $req, $res, $param) = @_;

    my $upload = $req->upload('g2_userfile');
    unless ($upload && $upload->size) {
        return $self->error($req, $res, {
            gr2  => {
                status => $UPLOAD_PHOTO_FAIL,
                status_text => "upload photo fail",
            },
        });
    }
    my $filename = $req->param('g2_userfile_name') || $upload->filename;
    unless ($filename) {
        return $self->error($req, $res, {
            gr2  => {
                status => $NO_FILENAME,
                status_text => "No Filename",
            },
        });
    }
    if (my $prefix = $param->{set_albumName}) {
        $filename = join '/', $prefix, $filename;
    }
    Doumeki::Log->log(notice => "[add_item ] uploading $filename");

    $self->call_trigger('add_item', $upload->tempname, $filename, $req)
        ? $self->success($req, $res, {
            gr2 => {
                status_text => 'Add photo successful',
                item_name   => $filename,
            }
           })
        : $self->error($req, $res, {
            gr2  => {
                status      => $UPLOAD_PHOTO_FAIL,
                status_text => "upload photo fail",
            },
        });
}

sub new_album {
    my($self, $req, $res, $param) = @_;

    my $album_name = $param->{newAlbumName} || $param->{newAlbumTitle};
    Doumeki::Log->log(debug => "new album_name: $album_name");

    $self->call_trigger('new_album', $album_name, $req)
        ? $self->success($req, $res, {
            gr2 => {
                status_text => 'New album created successful',
                album_name  => $album_name,
            },
        })
        : $self->error($req, $res, {
            gr2 => {
                status      => $CREATE_ALBUM_FAILED,
                status_text => 'New album created successful',
            },
        });
}

sub build_gr2_response {
    my($self, $gr2) = @_;

    $gr2->{status}         ||= $GR_STAT_SUCCESS;
    $gr2->{status_text}    ||= 'OK';
    $gr2->{server_version} ||= $SERVER_VERSION;

    my $body = "#__GR2PROTO__\n";
    for my $key( keys %{$gr2} ) {
        if (ref($gr2->{$key}) eq 'ARRAY') {
            my $n = 1;
            for my $sub_val(@{$gr2->{$key}}) {
                for my $sub_key( keys %{$sub_val} ) {
                    $body .= sprintf "%s.%s.%d=%s\n",
                        $key, $sub_key, $n, $sub_val->{$sub_key};
                }
                $n++;
           }
        } else {
            $body .= sprintf "%s=%s\n", $key, $gr2->{$key};
        }
    }
    return $body;
}

sub build_response {
    my($self, $res, $status) = @_;

    my ($code, $text);
    if (exists $status->{http} && %{$status->{http}}) {
        ($code, $text) = each %{ $status->{http} };
    } else {
        ($code, $text) = (200, "OK");
    }
    $res->status($code);

    my $body;
    if (exists $status->{gr2} && %{$status->{gr2}}) {
        $body = $self->build_gr2_response($status->{gr2});
    } else {
        $body = $text;
    }

    $res->headers->header('Content-Type' => 'text/plain');
    $res->body($body);

    Doumeki::Log->log(debug => "body: ".$res->body);
}

sub success {
    my($self, $req, $res, $status) = @_;

    $self->build_response($res, $status);

    Doumeki::Log->log(info => $status->{log}) if exists $status->{log};
    Doumeki::Log->log_request($req, $res);
    return $res;
}


sub error {
    my($self, $req, $res, $status) = @_;

    $self->build_response($res, $status);

    Doumeki::Log->log(error=> $status->{log}) if exists $status->{log};
    Doumeki::Log->log_request($req, $res);
    return $res;
}

1;
