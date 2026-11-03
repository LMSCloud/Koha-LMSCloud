#!/usr/bin/perl

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 2;
use Template;
use Test::MockModule;

use C4::Context;

subtest 'Asset.module_urls versions every module of a directory' => sub {
    plan tests => 4;

    my $koha_module = Test::MockModule->new("Koha");
    $koha_module->mock( "version", sub { return "25.11.10.000" } );

    my $template = Template->new( { PLUGIN_BASE => 'Koha::Template::Plugin' } );
    my $output   = '';
    $template->process(
        \'[% USE Asset %][% FOREACH module IN Asset.module_urls("js/fetch") %][% module.url %]=[% module.versioned %];[% END %]',
        { interface => '/intranet-tmpl', theme => 'prog' },
        \$output
    ) or die $template->error;

    my %urls = map { split /=/ } grep { length } split /;/, $output;

    my $root  = C4::Context->config('intrahtdocs');
    my @files = map { ( split m{/} )[-1] } glob("$root/prog/js/fetch/*.js");

    is( scalar keys %urls, scalar @files, 'one entry per module in the directory' );
    is(
        $urls{'/intranet-tmpl/prog/js/fetch/api-client.js'},
        '/intranet-tmpl/prog/js/fetch/api-client_25.1110000.js',
        'api-client.js maps to its versioned URL'
    );
    is(
        $urls{'/intranet-tmpl/prog/js/fetch/circulation-api-client.js'},
        '/intranet-tmpl/prog/js/fetch/circulation-api-client_25.1110000.js',
        'modules loaded through relative imports are listed too'
    );

    $output = '';
    $template->process(
        \'[% USE Asset %][% Asset.module_urls("js/no-such-directory").size %]',
        { interface => '/intranet-tmpl', theme => 'prog' },
        \$output
    );
    is( $output, '0', 'a missing directory gives no entries' );
};
