package WebService::Kavel;

use strict;
use warnings;
use HTTP::Tiny;
use JSON::PP qw(encode_json decode_json);
use Time::HiRes qw(time sleep);

our $VERSION = '0.01';

# Refusals answer HTTP 200 with code -1 and a human message.
sub new {
    my ($class, %args) = @_;
    my $self = bless {
        base_url        => $args{base_url} // 'https://www.kavel.ai',
        api_key         => $args{api_key} // $ENV{KAVEL_API_KEY} // '',
        model           => $args{model},
        poll_seconds    => $args{poll_seconds} // 5,
        timeout_seconds => $args{timeout_seconds} // 360,
        http            => HTTP::Tiny->new(timeout => 60, agent => "WebService-Kavel/$VERSION"),
    }, $class;
    return $self;
}

sub _fail { my ($reason, $msg) = @_; return { ok => 0, reason => $reason, message => "kavel: $msg" } }

sub _anon_id { return 'pl-' . join '', map { sprintf '%02x', int rand 256 } 1 .. 8 }

sub _request {
    my ($self, $method, $path, $headers, $body) = @_;
    my %opt = (headers => { %$headers });
    if (defined $body) {
        $opt{headers}{'Content-Type'} = 'application/json';
        $opt{content} = encode_json($body);
    }
    my $res = $self->{http}->request($method, $self->{base_url} . $path, \%opt);
    return (undef, _fail('other', "$res->{status} $res->{reason}")) if $res->{status} == 599;
    my $env = eval { decode_json($res->{content}) };
    return (undef, _fail('other', 'unexpected response')) unless ref $env eq 'HASH';
    if (($env->{code} // -1) != 0) {
        my $msg = $env->{message} // 'request refused';
        my $low = lc $msg;
        my $r = $low =~ /invalid api key/ ? 'auth'
              : $low =~ /insufficient credits/ ? 'quota'
              : $low =~ /sign in|subscription/ ? 'sign_in'
              : 'other';
        return (undef, _fail($r, $msg));
    }
    return ($env->{data} // {}, undef);
}

sub _run {
    my ($self, $payload) = @_;
    my $key  = $self->{api_key};
    my %auth = $key ne '' ? (Authorization => "Bearer $key") : ('x-anon-id' => _anon_id());
    my $deadline = time + $self->{timeout_seconds};

    my ($d, $err) = $self->_request('POST', '/api/ai/generate', \%auth, $payload);
    return $err if $err;
    # The quota wall answers 200 with code 0 and wall: true.
    if ($d->{wall}) {
        my $why = $d->{reason} // '';
        return _fail('quota', 'this machine has used its free credits for today') if $why eq 'anon_ip_daily';
        return _fail('sign_in', 'this needs a signed-in account') if $why eq 'anon_unmetered_video';
        return _fail('quota', 'the free allowance does not cover this run');
    }
    my $task = $d->{id} // return _fail('other', 'the service returned no task id');

    while (time < $deadline) {
        sleep $self->{poll_seconds};
        my ($p) = $key ne ''
            ? $self->_request('POST', '/api/ai/query', \%auth, { taskId => $task })
            : $self->_request('GET', '/api/ai/anon-query?taskId=' . _escape($task) . '&provider=kie&mediaType=image', \%auth);
        # Free runs only start when a poll crosses the end of the queue, so a
        # dropped poll is not a failed job: keep going.
        next unless $p;
        return { ok => 1, url => $p->{cleanImages}[0], watermarked => 0 } if @{ $p->{cleanImages} // [] };
        if (@{ $p->{images} // [] }) {
            my $wm = ($p->{watermarked} // [])->[0];
            return { ok => 1, url => $p->{images}[0], watermarked => ($wm && $wm eq '1') ? 1 : 0 };
        }
        return _fail('rejected', 'prompt refused; reword it') if ($p->{status} // '') =~ /^(failed|error)$/;
    }
    return _fail('timeout', 'no image before the deadline');
}

sub _escape { my $s = shift; $s =~ s/([^A-Za-z0-9\-_.~])/sprintf '%%%02X', ord $1/ge; return $s }

sub generate {
    my ($self, $prompt, %opt) = @_;
    return _fail('other', 'prompt is required') unless defined $prompt && $prompt =~ /\S/;
    my $model = ($self->{api_key} ne '' && $self->{model}) ? $self->{model} : 'kavel-image-v1';
    return $self->_run({
        provider => 'kie', mediaType => 'image', model => $model, scene => 'text-to-image',
        prompt => $prompt, options => { aspect_ratio => $opt{aspect_ratio} // '1:1' },
    });
}

sub edit {
    my ($self, $source_url, $instruction) = @_;
    return _fail('other', 'source_url must be a public http(s) url') unless ($source_url // '') =~ m{^https?://};
    return _fail('other', 'instruction is required') unless defined $instruction && $instruction =~ /\S/;
    my $model = ($self->{api_key} ne '' && $self->{model}) ? $self->{model} : 'nano-banana-2-lite';
    return $self->_run({
        provider => 'kie', mediaType => 'image', model => $model, scene => 'image-to-image',
        prompt => $instruction, options => { image_input => [$source_url] },
    });
}

sub credits {
    my ($self) = @_;
    my ($d, $err) = $self->_request('GET', '/api/ai/anon-credits', { 'x-anon-id' => _anon_id() });
    return $err if $err;
    return { ok => 1, remaining => $d->{remaining}, grant => $d->{grant} };
}

1;

__END__

=head1 NAME

WebService::Kavel - Generate AI images with no API key and no account

=head1 SYNOPSIS

  use WebService::Kavel;
  my $kavel = WebService::Kavel->new;
  my $r = $kavel->generate('matte black ceramic mug on pale oak, soft window light',
                           aspect_ratio => '16:9');
  print $r->{ok} ? "$r->{url}\n" : "$r->{reason}: $r->{message}\n";

=head1 DESCRIPTION

A small client for the Kavel AI image service (L<https://www.kavel.ai>). Without a key it
uses the anonymous free tier, so the first call works on a machine with nothing configured.
Pass C<api_key> (or set C<KAVEL_API_KEY>) to run on your account. Core modules only,
plus L<IO::Socket::SSL> for HTTPS.

Every call returns a hashref. On failure C<ok> is false and C<reason> is one of
C<quota> (wait, or pass a key), C<rejected> (reword the prompt), C<sign_in>, C<auth>,
C<timeout> or C<other>.

=head1 METHODS

=head2 generate($prompt, aspect_ratio => '1:1')

Turns a prompt into a new image. Returns C<url> and C<watermarked>.

=head2 edit($source_url, $instruction)

Rewrites the image at a public url. An edit costs more than the free allowance, so without
a key this returns C<quota> before anything is charged.

=head2 credits

What a fresh anonymous client id is granted. Free to call.

=head1 LICENSE

MIT.

=cut
