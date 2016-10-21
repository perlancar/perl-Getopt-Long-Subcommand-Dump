package Getopt::Long::Subcommand::Dump;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(dump_getopt_long_subcommand_script);

our %SPEC;

$SPEC{dump_getopt_long_subcommand_script} = {
    v => 1.1,
    summary => 'Run a Getopt::Long::Subcommand-based script but only to '.
        'dump the spec',
    description => <<'_',

This function runs a CLI script that uses `Getopt::Long::Subcommand` but
monkey-patches beforehand so that `run()` will dump data structure and then
exit. The goal is to get the object without actually running the script.

This can be used to gather information about the script and then generate
documentation about it or do other things (e.g. `App::shcompgen` to generate a
completion script for the original script).

CLI script needs to use `Getopt::Long::Subcommand`. This is detected currently
by a simple regex. If script is not detected as using `Getopt::Long`, status 412
is returned.

Will return the `Getopt::Long::Subcommand` specification.

_
    args => {
        filename => {
            summary => 'Path to the script',
            req => 1,
            schema => 'str*',
        },
        libs => {
            summary => 'Libraries to unshift to @INC when running script',
            schema  => ['array*' => of => 'str*'],
        },
    },
};
sub dump_getopt_long_script {
    require Capture::Tiny;
    require Getopt::Long::Subcommand::Util;
    require UUID::Random;

    my %args = @_;

    my $filename = $args{filename} or return [400, "Please specify filename"];
    my $detres = Getopt::Long::Subcommand::Util::detect_getopt_long_subcommand_script(
        filename => $filename);
    return $detres if $detres->[0] != 200;
    return [412, "File '$filename' is not script using Getopt::Long::Subcommand (".
        $detres->[3]{'func.reason'}.")"] unless $detres->[2];

    my $libs = $args{libs} // [];

    my $tag = UUID::Random::generate();
    my @cmd = (
        $^X, (map {"-I$_"} @$libs),
        "-MGetopt::Long::Subcommand::Patch::DumpAndExit=-tag,$tag",
        $filename,
        "--version",
    );
    my ($stdout, $stderr, $exit) = Capture::Tiny::capture(
        sub { local $ENV{GETOPT_LONG_SUBCOMMAND_DUMP} = 1; system @cmd },
    );

    my $spec;
    if ($stdout =~ /^# BEGIN DUMP $tag\s+(.*)^# END DUMP $tag/ms) {
        $spec = eval $1;
        if ($@) {
            return [500, "Script '$filename' detected as using ".
                        "Getopt::Long::Subcommand, but error in eval-ing captured ".
                            "option spec: $@, raw capture: <<<$1>>>"];
        }
        if (ref($spec) ne 'HASH') {
            return [500, "Script '$filename' detected as using ".
                        "Getopt::Long::Subcommand, but didn't get a hash option spec, ".
                            "raw capture: stdout=<<$stdout>>"];
        }
    } else {
        return [500, "Script '$filename' detected as using Getopt::Long::Subcommand, ".
                    "but can't capture option spec, raw capture: ".
                        "stdout=<<$stdout>>, stderr=<<$stderr>>"];
    }

    [200, "OK", $spec, {
        'func.detect_res' => $detres,
    }];
}

1;
# ABSTRACT:

=head1 ENVIRONMENT

=head2 GETOPT_LONG_SUBCOMMAND_DUMP => bool

Will be set to 1 when executing the script to be dumped.


=head1 SEE ALSO

L<Getopt::Long::Dump>
