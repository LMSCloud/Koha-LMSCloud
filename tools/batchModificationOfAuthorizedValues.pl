#!/usr/bin/perl

# Copyright 2025 LMSCloud GmbH
#
# This file is part of Koha.
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
use Text::CSV;

use C4::Auth qw(get_template_and_user);
use CGI qw ( -utf8 );
use C4::Context;
use C4::Koha;
use C4::Output qw(output_html_with_http_headers);

use Koha::AuthorisedValueCategories;
use Koha::AuthorisedValues;

=head1 batchModificationOfAuthorizedValues.pl

Modify authorized values using a CSV-file with the following rules

AuthValueOld;AuthValueNew;AuthDescriptionNew;AuthDescriptionOpacNew;

=cut

my $input = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/batchModificationOfAuthorizedValues.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { parameters => 'manage_auth_values' },
        debug           => 1,
    }
);

my $action = $input->param("action");
$action = "upload_file" if (! $action );
my $category =  $input->param("category");
my $category_values = [];
my $errors = [];

if ( $category ) {
    my $category_exists = Koha::AuthorisedValueCategories->find(
        {
            category_name => $category,
        }
    );
    if ( $category_exists ) {
        my $authorisedValueSearch = Koha::AuthorisedValues->search({ category => $category },{ order_by => ['authorised_value'] } );
        if ( $authorisedValueSearch->count ) {
            while ( my $authval = $authorisedValueSearch->next ) {
                push @$category_values, $authval->unblessed;
            }
        }
    } else {
        push @$errors, { type => "category", error => "invalid_category" };
        $category = undef;
    }
}

my $line_actions = 0;
my $line_errors = 0;
        
if ( $action eq 'check_update' && $category && @$category_values ) {
    
    # The uploaded file filehandle,
    # which we may or may not have been passed
    my $csvfile = $input->upload("csvfile");
    
    my $csv = Text::CSV->new ({ binary => 1, 
                                sep_char => ";",  
                                quote_char => '"', 
                                escape_char => '"', 
                                always_quote => 0,
                                quote_space  => 0,
                                quote_null   => 0,
                                decode_utf8  => 1
                            });
    
    my $rules = [];
    
    if ($csvfile) {
        # Call binmode on the filehandle as we want to set a
        # UTF-8 layer on it
        binmode($csvfile, ":encoding(UTF-8)");
        # Parse the file into an array of barcodes
        my $linenumber = 0;
        eval {
            while (my $csvline = $csv->getline ($csvfile) ) {
                $linenumber++;
                my $lineaction;
                my $lineerror;
                if ( $csvline->[0] || $csvline->[1] ) {
                    if ( $csvline->[2] && ! $csvline->[3] ) {
                        $csvline->[3] = $csvline->[2]
                    }
                    if (! $csvline->[0] ) {
                        my $exists = 0;
                        foreach my $categ(@$category_values) {
                            $exists = 1 if ( $categ->{authorised_value} eq $csvline->[1] );
                        }
                        if (! $exists) {
                            $lineaction =  {
                                            do => 'add',
                                            authorised_value => $csvline->[1],
                                            lib => $csvline->[2],
                                            lib_opac => $csvline->[3]
                                        } ;
                            push @$category_values, $lineaction;
                        } else {
                            $lineerror = { type => "csv", line => $linenumber, error => "exists", action => 'add' };
                            $lineaction =  {
                                            do => 'add',
                                            authorised_value => $csvline->[1],
                                            lib => $csvline->[2],
                                            lib_opac => $csvline->[3]
                                        } ;
                        }
                    }
                    elsif (! $csvline->[1] ) {
                        my $delete = undef;
                        my $index = 0;
                        foreach my $categ(@$category_values) {
                            $delete = $categ if ( $categ->{authorised_value} eq $csvline->[0] );
                            $index++;
                        }
                        if ($delete) {
                            splice(@$category_values,$index,1);
                            $lineaction =   {
                                            do => 'delete',
                                            authorised_value => $delete->{authorised_value},
                                            lib => $delete->{lib},
                                            lib_opac => $delete->{lib_opac}
                                        };
                        } else {
                            $lineerror = { type => "csv", line => $linenumber, error => "not_exists", action => 'delete' };
                            $lineaction =   {
                                            do => 'delete',
                                            authorised_value => $csvline->[0],
                                            lib => "",
                                            lib_opac => ""
                                        };
                        }
                    }
                    else {
                        my $update = undef;
                        my $index = 0;
                        foreach my $categ(@$category_values) {
                            $update = $categ if ( $categ->{authorised_value} eq $csvline->[0] );
                            $index++;
                        }
                        my $new = undef;
                        foreach my $categ(@$category_values) {
                            $new = $categ if ( $categ->{authorised_value} eq $csvline->[1] && !($update && $update->{id} == $categ->{id}));
                            $index++;
                        }
                        if ($update && !$new) {
                            $lineaction =   {
                                            do => 'update',
                                            old_authorised_value => $update->{authorised_value},
                                            old_lib => $update->{lib},
                                            old_lib_opac => $update->{lib_opac},
                                            authorised_value => $csvline->[1],
                                            lib => $csvline->[2],
                                            lib_opac => $csvline->[3],
                                        };
                            
                            # update authorized value
                            $update->{authorised_value} = $csvline->[1];
                            $update->{lib} = $csvline->[2];
                            $update->{lib_opac} = $csvline->[3];
                            
                        } elsif ( $new ) {
                            $lineerror = { type => "csv", line => $linenumber, error => "exists", action => 'update' };
                            $lineaction =   {
                                            do => 'update',
                                            old_authorised_value => $csvline->[0],
                                            old_lib => "",
                                            old_lib_opac => "",
                                            authorised_value => $csvline->[1],
                                            lib => $csvline->[2],
                                            lib_opac => $csvline->[3],
                                        };
                            if ( $update ) {
                                $lineaction->{old_authorised_value} = $update->{authorised_value};
                                $lineaction->{old_lib} = $update->{lib};
                                $lineaction->{old_lib_opac} = $update->{lib_opac};
                            }
                        } elsif (! $update) {
                            $lineerror = { type => "csv", line => $linenumber, error => "not_exists", action => 'update' };
                            $lineaction =   {
                                            do => 'update',
                                            old_authorised_value => $csvline->[0],
                                            old_lib => "",
                                            old_lib_opac => "",
                                            authorised_value => $csvline->[1],
                                            lib => $csvline->[2],
                                            lib_opac => $csvline->[3],
                                        };
                        } else {
                            $lineerror = { type => "csv", line => $linenumber, error => "unknown", action => 'update' };
                            $lineaction =   {
                                            do => 'update',
                                            old_authorised_value => $csvline->[0],
                                            old_lib => "",
                                            old_lib_opac => "",
                                            authorised_value => $csvline->[1],
                                            lib => $csvline->[2],
                                            lib_opac => $csvline->[3],
                                        };
                            if ( $update ) {
                                $lineaction->{old_authorised_value} = $update->{authorised_value};
                                $lineaction->{old_lib} = $update->{lib};
                                $lineaction->{old_lib_opac} = $update->{lib_opac};
                            }
                        }
                    }
                }
                elsif ( $csvline->[2] || $csvline->[3] ) {
                    $lineerror = { type => "csv", line => $linenumber, error => "no_value", action => 'no' };
                }
                my $rule = { 
                            oldValue => $csvline->[0], 
                            newValue => $csvline->[1], 
                            newDescription => $csvline->[2], 
                            newDescriptionOpac => $csvline->[3]
                          };
                $rule->{error} = $lineerror if ( $lineerror );
                $rule->{action} = $lineaction if ( $lineaction );
                
                push @$rules, $rule;
                
                $line_errors++ if ($lineerror);
                $line_actions++ if ($lineaction);
            }
        };
        if ( $@ ) {
            push @$errors, { type => "csv", line => $linenumber+1, error => "read_error", text => $@ };
        }
    }
    else {
        push @$errors, { type => "csv", error => "no_file" };
    }
    if (! @$rules ) {
        push @$errors, { type => "csv", error => "no_values" };
    }
    if (! scalar(@$errors) ) {
        $template->param( 
            rules => $rules,  
            line_errors => $line_errors,
            line_actions => $line_actions
        );
        $action = "confirm_actions";
    }
}
elsif ( $action eq 'do_update' && $category ) {
    my ($deleted,$updated,$created)=(0,0,0);
    my $actioncount = $input->param("actioncount");
    my $actionresults = [];
    if ( $actioncount &&  $actioncount =~ /^\d+$/ && $actioncount > 0 ) {
        for (my $i=1; $i<=$actioncount; $i++) {
            my $action = $input->param("action_$i");
            my $authorised_value = $input->param("authorised_value_$i");
            my $lib = $input->param("lib_$i");
            my $lib_opac = $input->param("lib_opac_$i");
            my $select = $input->param("select_$i");
             
            my $actionresult = { result => 0, action => $action, authorised_value => $authorised_value, lib => $lib, lib_opac => $lib_opac, select => $select };
            
            if ( $action eq 'delete' && $authorised_value ) {
                my $authorisedValueSearch = Koha::AuthorisedValues->search({ category => $category, authorised_value => $authorised_value } );
                if ( $authorisedValueSearch->count == 1 ) {
                    while ( my $authval = $authorisedValueSearch->next ) {
                        $authval->delete;
                        $deleted++;
                        $actionresult->{result} = 1;
                    }
                }
            }
            elsif ( $action eq 'add' && $authorised_value ) {
                my $authval = Koha::AuthorisedValue->new(
                                            { 
                                                category => $category, 
                                                authorised_value => $authorised_value,
                                                lib => $lib,
                                                lib_opac => $lib_opac
                                            } );
                $authval->store;
                $created++;
                $actionresult->{result} = 1;
            }
            elsif ( $action eq 'update' && $authorised_value ) {
                my $authorisedValueSearch = Koha::AuthorisedValues->search({ category => $category, authorised_value => $select } );
                if ( $authorisedValueSearch->count == 1 ) {
                    while ( my $authval = $authorisedValueSearch->next ) {
                        $authval->set(
                                            { 
                                                authorised_value => $authorised_value,
                                                lib => $lib,
                                                lib_opac => $lib_opac 
                                            });
                        $authval->store;
                        $updated++;
                        $actionresult->{result} = 1;
                    }
                }
            }
            push @$actionresults, $actionresult;
        }

        $template->param( 
            deleted => $deleted,  
            updated => $updated,
            created => $created,
            actionresults => $actionresults
        );
        $action = "update_result";
    }
}

if ( scalar(@$errors) ) {
    $template->param( errors => $errors );
    $action = "upload_file";
}

my @categories = Koha::AuthorisedValueCategories->search( { category_name => { '!=' => '' } },{ order_by => ['category_name'] } )->get_column('category_name');

$template->param(
    categories  => \@categories,
    action      => $action,
    category    => $category,
);

output_html_with_http_headers $input, $cookie, $template->output;
