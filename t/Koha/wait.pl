#!/usr/bin/perl

use Modern::Perl;

use Koha::Script;
use Fcntl qw(:flock);
use Try::Tiny;

# # Lock execution
my $script = Koha::Script->new({ script => 'sleep.pl' });

$script->lock_exec({ wait => 1 });

print STDOUT "YAY!";

# Normal exit
1;
