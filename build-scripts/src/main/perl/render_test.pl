#!/usr/bin/perl

package render_app;

use warnings;
use strict;

BEGIN {
    unshift(@INC, '/usr/lib/perl');
}

use parent qw(CAF::Application CAF::Reporter);

use Test::Quattor::ProfileCache qw(prepare_profile_cache);
use CAF::Object qw (SUCCESS);
use EDG::WP4::CCM::Path qw(unescape);
use EDG::WP4::CCM::TextRender;
use Readonly;

Readonly my $METACONFIG_SERVICES => "/software/components/metaconfig/services";

sub app_options
{

    my @options = (
        {
            NAME    => "profile|p=s",
            HELP    => 'Profile to use',
        },
        {
            NAME    => "metaconfigservice|m=s",
            HELP    => 'Metaconfig service to render (treated as a regex pattern)',
        },

    );

    return \@options;
};

sub render
{
    my ($self) = @_;

    if (!$self->option('profile')) {
        $self->error("Provide path to compiled profile");
        return;
    };

    my $pattern = $self->option('metaconfigservice');
    if (! defined $pattern) {
        $self->error("Provide metaconfigservice to render");
        return;
    };

    my $cfg = prepare_profile_cache($self->option('profile'), 1);
    my $allsrvs = $cfg->getTree($METACONFIG_SERVICES, 2);
    if ($allsrvs) {
        my @srvs = grep {unescape($_) =~ m/$pattern/} sort keys %$allsrvs;
        foreach my $escsrv (@srvs) {
            my $srv = unescape($escsrv);
            my $inst = $allsrvs->{$escsrv};

            my $trd = EDG::WP4::CCM::TextRender->new(
                $inst->{module}->getValue,
                $inst->{contents},
                log => $self,
                eol => 0,
                element => $inst->{convert} ? $inst->{convert}->getTree() : {},
                );
            $trd->get_text();
            if ($trd->{fail}) {
                $self->error("Failed to render $srv: $trd->{fail}");
            } else {
                print "$srv\n$trd\n";
            };
        };
    } else {
        $self->error("No metaconfig services defined");
    }
};

package main;
use strict;
use warnings;

=head1 NAME render_test

Render metaconfigservices from already compiled profiles.

=head1 Example

    render_test.pl -p /path/to/hostname.json.gz -m configname

    Will render all metaconfig services matching 'configname' configured in compiled profile.

=head1 CAVEATS / TODO

TODO: The TT files are taken from standard ncm-metaconfig location,
      so you need ncm-metaconfig installed (or copy them manually in /usr/share/templates/quattor).

TODO: temp cache is now created in target subdir in current directory. Use /tmp/$USER or something like that

TODO: it's very chatty, mainly due to chatty nature of the mocking here and there.

=cut

my $this_app;

if ($this_app = render_app->new($0,@ARGV)) {
    $this_app->render();
}
