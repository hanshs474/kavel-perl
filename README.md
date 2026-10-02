# WebService::Kavel

Generate AI images from Perl with **no API key and no account**.

```perl
use WebService::Kavel;
my $r = WebService::Kavel->new->generate(
    'matte black ceramic mug on pale oak, soft window light', aspect_ratio => '16:9');
print $r->{ok} ? "$r->{url}\n" : "$r->{reason}: $r->{message}\n";
```

Calls the anonymous tier of [Kavel](https://www.kavel.ai/?utm_source=cpan&utm_medium=package), an
online AI image and video studio, so the first call works on a machine with nothing configured.
Core modules only, plus IO::Socket::SSL for HTTPS. On 2026-10-02 a fresh client id was granted 5
credits and one generated image spent all five; free output is 1K and watermarked. Editing needs an
API key from [kavel.ai/settings/apikeys](https://www.kavel.ai/settings/apikeys?utm_source=cpan&utm_medium=package).

MIT licensed.
