#!/usr/bin/perl

# This file is part of Koha.
#
# Copyright 2019 Koha Development Team
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );

use Koha::Script;

use C4::Context;
use Koha::Plugins;

my ($help);
GetOptions( 'help|?' => \$help );

pod2usage(1) if $help;

unless ( C4::Context->config("enable_plugins") ) {
    print
"The plugin system must be enabled for one to be able to install plugins\n";
    exit 1;
}

my @existing_plugins = Koha::Plugins->new()->GetPlugins({
    all    => 1,
    errors => 1,
});
my $existing_plugins;
for my $existing_plugin (@existing_plugins) {
    if( defined $existing_plugin->{error} ){
        print "Could not load: ".$existing_plugin->{name}." any associated method will be removed\n";
    } else {
        $existing_plugins->{ $existing_plugin->{metadata}->{name} } =
          $existing_plugin->{metadata}->{version};
    }
}

my @installed_plugins = Koha::Plugins->new()->InstallPlugins();
unless (@installed_plugins) {
    my $plugins_dir = C4::Context->config("pluginsdir");
    if ( ref($plugins_dir) eq 'ARRAY' ) {
        print "No plugins found\n";
        print "pluginsdir contains: \n" . join( '\n', @{$plugins_dir} );
    }
    else {
        print "No plugins found at $plugins_dir\n";
    }
    exit 0;
}

for my $installed_plugin (@installed_plugins) {
    if ( !exists( $existing_plugins->{ $installed_plugin->{metadata}->{name} } )
      )
    {
        print "Installed "
          . $installed_plugin->{metadata}->{name}
          . " version "
          . $installed_plugin->{metadata}->{version} . "\n";
    }
    elsif ( $existing_plugins->{ $installed_plugin->{metadata}->{name} } ne
        $installed_plugin->{metadata}->{version} )
    {
        print "Upgraded "
          . $installed_plugin->{metadata}->{name}
          . " from version "
          . $existing_plugins->{ $installed_plugin->{metadata}->{name} }
          . " to version "
          . $installed_plugin->{metadata}->{version} . "\n";
    }
}
print "All plugins successfully re-initialised\n";

=head1 NAME

install_plugins.pl - install all plugins found in plugins_dir

=head1 SYNOPSIS

 install_plugins.pl

Options:
  -?|--help        brief help message

=head1 OPTIONS

=over 8

=item B<--help|-?>

Print a brief help message and exits

=back

=head1 DESCRIPTION

A simple script to install plugins from the command line

=cut
