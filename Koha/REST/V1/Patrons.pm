package Koha::REST::V1::Patrons;

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

use Mojo::Base 'Mojolicious::Controller';

use Koha::Database;
use Koha::Exceptions;
use Koha::Patrons;

use List::MoreUtils qw(any);
use Scalar::Util qw( blessed );
use Try::Tiny qw( catch try );
use JSON;
use Data::Dumper;

=head1 NAME

Koha::REST::V1::Patrons

=head1 API

=head2 Methods

=head3 list

Controller function that handles listing Koha::Patron objects

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $query = {};
        my $restricted = delete $c->validation->output->{restricted};
        $query->{debarred} = { '!=' => undef }
            if $restricted;
        
        if ( exists $c->validation->output->{q} ) {
			my $q_param = $c->validation->output->{q};
			my $addional_params = _extract_additional_params($q_param);
			_add_additional_params_to_query($addional_params,$query);
		}

        my $patrons_rs = Koha::Patrons->search($query);
        my $patrons    = $c->objects->search( $patrons_rs );

        return $c->render(
            status  => 200,
            openapi => $patrons
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

sub _add_additional_params_to_query {
	my $addional_params = shift;
	my $query = shift;
	
	if ( $addional_params ) {
		$query->{'-and'} = [];
		if ( exists($addional_params->{'age_from'}) && exists($addional_params->{'age_to'}) && $addional_params->{'age_from'} =~ /^\d+$/ && $addional_params->{'age_to'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ 'TIMESTAMPDIFF(YEAR,me.dateofbirth,CURDATE()) BETWEEN ? AND ?', $addional_params->{'age_from'}, $addional_params->{'age_to'} ];
		}
		elsif ( exists($addional_params->{'age_from'}) && $addional_params->{'age_from'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ 'TIMESTAMPDIFF(YEAR,me.dateofbirth,CURDATE()) >= ?', $addional_params->{'age_from'} ];
		}
		elsif ( exists($addional_params->{'age_to'}) && $addional_params->{'age_to'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ 'TIMESTAMPDIFF(YEAR,me.dateofbirth,CURDATE()) <= ?', $addional_params->{'age_to'} ];
		}
		
		if ( exists($addional_params->{'issue_count_from'}) && exists($addional_params->{'issue_count_to'}) && $addional_params->{'issue_count_from'} =~ /^\d+$/ && $addional_params->{'issue_count_to'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ '(SELECT COUNT(*) FROM issues iss WHERE iss.borrowernumber = me.borrowernumber) BETWEEN ? AND ?', $addional_params->{'issue_count_from'}, $addional_params->{'issue_count_to'} ];
		}
		elsif ( exists($addional_params->{'issue_count_from'}) && $addional_params->{'issue_count_from'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ '(SELECT COUNT(*) FROM issues iss WHERE iss.borrowernumber = me.borrowernumber) >= ?', $addional_params->{'issue_count_from'} ];
		}
		elsif ( exists($addional_params->{'issue_count_to'}) && $addional_params->{'issue_count_to'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ '(SELECT COUNT(*) FROM issues iss WHERE iss.borrowernumber = me.borrowernumber) <= ?', $addional_params->{'issue_count_to'} ];
		}
		
		if ( exists($addional_params->{'charges_from'}) && $addional_params->{'charges_from'} =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
			$addional_params->{'charges_from'} += 0.0;
		} else {
			delete $addional_params->{'charges_from'};
		}
		if ( exists($addional_params->{'charges_to'}) && $addional_params->{'charges_to'} =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
			$addional_params->{'charges_to'} += 0.0;
		} else {
			delete $addional_params->{'charges_to'};
		}
		if ( exists($addional_params->{'charges_from'}) && exists($addional_params->{'charges_to'}) && $addional_params->{'charges_from'} =~ /^[0-9]+(\.+[0-9]+)?$/ && $addional_params->{'charges_to'} =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
			my $add = "( EXISTS (SELECT 1 FROM accountlines a WHERE a.borrowernumber = me.borrowernumber GROUP BY a.borrowernumber HAVING ";
            if ( $addional_params->{'charges_from'} == 0.0 && $addional_params->{'charges_to'} == 0.0 ) {
                $add .= "COALESCE(SUM(a.amountoutstanding),0) = 0.0) OR NOT EXISTS (SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = me.borrowernumber) )";
                push @{$query->{'-and'}}, \[ $add ];
            } else {
                $add .= "COALESCE(SUM(a.amountoutstanding),0) BETWEEN ? AND ?) ";
                $add .= "OR NOT EXISTS ( SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = me.borrowernumber) " if ( ( $addional_params->{'charges_from'} == 0.0 || $addional_params->{'charges_to'} == 0.0 ) && $addional_params->{'charges_to'} >= $addional_params->{'charges_from'} );
                $add .= " )";
                push @{$query->{'-and'}}, \[ $add, $addional_params->{'charges_from'}, $addional_params->{'charges_to'} ];
            }
		}
		elsif ( exists($addional_params->{'charges_from'}) && $addional_params->{'charges_from'} =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
			my $add = "( EXISTS (SELECT 1 FROM accountlines a WHERE a.borrowernumber = me.borrowernumber GROUP BY a.borrowernumber HAVING ";
			$add .= "SUM(a.amountoutstanding) >= ?) ";
            $add .= "OR NOT EXISTS (SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = me.borrowernumber) " if ( $addional_params->{'charges_from'} == 0.0 );
            $add .= " )";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'charges_from'} ];
		}
		elsif ( exists($addional_params->{'charges_to'}) && $addional_params->{'charges_to'} =~ /^[0-9]+(\.+[0-9]+)?$/ ) {
			my $add = "( EXISTS (SELECT 1 FROM accountlines a WHERE a.borrowernumber = me.borrowernumber GROUP BY a.borrowernumber HAVING ";
			$add .= "SUM(a.amountoutstanding) <= ?) ";
            $add .= "OR NOT EXISTS (SELECT 1 FROM accountlines aa WHERE aa.borrowernumber = me.borrowernumber) " if ( $addional_params->{'charges_to'} == 0.0 );
            $add .= " )";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'charges_to'} ];
		}
		if ( exists($addional_params->{'charges_period_from'}) && $addional_params->{'charges_period_from'} =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
			my $add = "EXISTS (SELECT 1 FROM accountlines al WHERE al.borrowernumber = me.borrowernumber AND al.amountoutstanding >= 0.01 and al.date <= ?)";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'charges_period_from'} ];
		}
		if ( exists($addional_params->{'account_expiry_from'}) && $addional_params->{'account_expiry_from'} =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
			my $add = "me.dateexpiry >= ?";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'account_expiry_from'} ];
		}
		if ( exists($addional_params->{'account_expiry_to'}) && $addional_params->{'account_expiry_to'} =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
			my $add = "me.dateexpiry <= ?";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'account_expiry_to'} ];
		}
		if ( exists($addional_params->{'debarred_period_from'}) && $addional_params->{'debarred_period_from'} =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
			my $add = "me.debarred >= ?";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'debarred_period_from'} ];
		}
		if ( exists($addional_params->{'debarred_period_to'}) && $addional_params->{'debarred_period_to'} =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/ ) {
			my $add = "me.debarred <= ?";
			push @{$query->{'-and'}}, \[ $add, $addional_params->{'debarred_period_to'} ];
		}
		if ( exists($addional_params->{'inactive_period_from'}) && $addional_params->{'inactive_period_from'} =~ /^([0-9]{4}-[0-9]{2}-[0-9]{2})/ ) {
			my $activeto = "$1 00:00:00";
			my $inactivesince = "$1 23:59:59";
			push @{$query->{'-and'}}, \[ 'NOT EXISTS (SELECT 1 FROM issues iss WHERE iss.borrowernumber = me.borrowernumber AND iss.timestamp > ?)', $inactivesince ];
			push @{$query->{'-and'}}, \[ 'NOT EXISTS (SELECT 1 FROM old_issues oiss WHERE oiss.borrowernumber = me.borrowernumber AND oiss.timestamp > ?)', $inactivesince ];
			push @{$query->{'-and'}}, \[ '(me.lastseen < ? OR me.lastseen IS NULL)', $activeto ];
		}
		if ( exists($addional_params->{'last_letter'}) && $addional_params->{'last_letter'} !~ /^\s*$/ ) {
			push @{$query->{'-and'}}, \[ 'EXISTS (SELECT 1 FROM message_queue m WHERE m.borrowernumber = me.borrowernumber AND m.letter_code = ? and m.time_queued = (SELECT MAX(time_queued) FROM message_queue mq WHERE mq.borrowernumber = me.borrowernumber and status = ?))', $addional_params->{'last_letter'}, 'sent'];
		}
		if ( exists($addional_params->{'overdue_level'}) && $addional_params->{'overdue_level'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ 'EXISTS (SELECT 1 FROM issues i WHERE i.borrowernumber = me.borrowernumber AND ? IN (SELECT max(claim_level) FROM overdue_issues o WHERE i.issue_id = o.issue_id GROUP BY o.issue_id))', $addional_params->{'overdue_level'} ];
		}
		if ( exists($addional_params->{'valid_email'}) && $addional_params->{'valid_email'} eq 'yes' ) {
			push @{$query->{'-and'}}, \[ '(me.email REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\' OR '.
                                         'me.emailpro REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\')' ];
		}
		if ( exists($addional_params->{'valid_email'}) && $addional_params->{'valid_email'} eq 'no' ) {
			push @{$query->{'-and'}}, \[ '(me.email NOT REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\' OR me.email IS NULL) AND ' .
                                         '(me.emailpro NOT REGEXP \'^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\.[a-zA-Z]{2,4}$\' OR me.emailpro IS NULL)' ];
		}
		if ( exists($addional_params->{'patron_list'}) && $addional_params->{'patron_list'} =~ /^\d+$/ ) {
			push @{$query->{'-and'}}, \[ 'EXISTS (SELECT 1 FROM  patron_list_patrons p WHERE p.patron_list_id = ? AND p.borrowernumber = me.borrowernumber )', $addional_params->{'patron_list'} ];
		}
	}
}

sub _extract_additional_params {
	my $params = shift;
	my $additional_params = {};
	
	my @reserved_words = qw( age_from age_to issue_count_from issue_count_to charges_from charges_to charges_period_from account_expiry_from account_expiry_to debarred_period_from debarred_period_to inactive_period_from last_letter overdue_level valid_email patron_list);
	
	my $json = JSON->new;
	
	# print STDERR "Params is a: ", ref($params), "\n";
	
	if ( ref($params) eq 'ARRAY' ) {
		my $newarray = [];
		my $found = 0;
		foreach my $param (@$params) {
			# print STDERR Dumper(\$param);
			my $q_param = $json->decode( $param );
			# print STDERR Dumper(\$q_param);
			# print STDERR "Param q_param is a: ", ref($q_param), "\n";
			if ( ref($q_param) eq 'HASH' && exists($q_param->{"-and"}) ) {
				my $newlist = [];
				foreach my $lparam( @{$q_param->{"-and"}} ) {
					if ( ref($lparam) eq 'HASH' ) {
						foreach my $add_param(@reserved_words) {
							if ( exists($lparam->{$add_param}) ) {
								$additional_params->{$add_param} = $lparam->{$add_param};
								delete $lparam->{$add_param};
								$found = 1;
							}
						}
						if ( scalar(keys %$lparam) ) {
							push @$newlist, $lparam;
						}
					}
					else {
						push @$newlist, $lparam;
					}
				}
				if ( $found ) {
					$q_param->{"-and"} = $newlist;
				}
			} 
			elsif ( ref($q_param) eq 'HASH' )  {
				foreach my $add_param(@reserved_words) {
					if ( exists($q_param->{$add_param}) ) {
						$additional_params->{$add_param} = $q_param->{$add_param};
						delete $q_param->{$add_param};
						$found = 1;
					}
				}
			}
			$param = $json->encode( $q_param ) if ( $found );
			push @$newarray,$param;
			# print STDERR Dumper(\$param);
		}
	}
	
	return $additional_params;
}

=head3 get

Controller function that handles retrieving a single Koha::Patron object

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron_id = $c->validation->param('patron_id');
        my $patron    = $c->objects->find( Koha::Patrons->search_limited, $patron_id );

        unless ($patron) {
            return $c->render(
                status  => 404,
                openapi => { error => "Patron not found." }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $patron
        );
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 add

Controller function that handles adding a new Koha::Patron object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {

        Koha::Database->new->schema->txn_do(
            sub {

                my $body = $c->validation->param('body');

                my $extended_attributes = delete $body->{extended_attributes} // [];

                my $patron = Koha::Patron->new_from_api($body)->store;
                $patron->extended_attributes(
                    [
                        map { { code => $_->{type}, attribute => $_->{value} } }
                          @$extended_attributes
                    ]
                );
                if ( C4::Context->preference('EnhancedMessagingPreferences') ) {
                    C4::Members::Messaging::SetMessagingPreferencesFromDefaults(
                        {
                            borrowernumber => $patron->borrowernumber,
                            categorycode   => $patron->categorycode,
                        }
                    );
                }

                $c->res->headers->location($c->req->url->to_string . '/' . $patron->borrowernumber);
                return $c->render(
                    status  => 201,
                    openapi => $patron->to_api
                );
            }
        );
    }
    catch {

        my $to_api_mapping = Koha::Patron->new->to_api_mapping;

        if ( blessed $_ ) {
            if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
                return $c->render(
                    status  => 409,
                    openapi => { error => $_->error, conflict => $_->duplicate_id }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->broken_fk }
                            . " does not exist"
                    }
                );
            }
            elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
                return $c->render(
                    status  => 400,
                    openapi => {
                            error => "Given "
                            . $to_api_mapping->{ $_->parameter }
                            . " does not exist"
                    }
                );
            }
            elsif (
                $_->isa('Koha::Exceptions::Patron::MissingMandatoryExtendedAttribute')
              )
            {
                return $c->render(
                    status  => 400,
                    openapi => { error => "$_" }
                );
            }
            elsif (
                $_->isa('Koha::Exceptions::Patron::Attribute::InvalidType')
              )
            {
                return $c->render(
                    status  => 400,
                    openapi => { error => "$_" }
                );
            }
            elsif (
                $_->isa('Koha::Exceptions::Patron::Attribute::NonRepeatable')
              )
            {
                return $c->render(
                    status  => 400,
                    openapi => { error => "$_" }
                );
            }
            elsif (
                $_->isa('Koha::Exceptions::Patron::Attribute::UniqueIDConstraint')
              )
            {
                return $c->render(
                    status  => 400,
                    openapi => { error => "$_" }
                );
            }
        }

        $c->unhandled_exception($_);
    };
}


=head3 update

Controller function that handles updating a Koha::Patron object

=cut

sub update {
    my $c = shift->openapi->valid_input or return;

    my $patron_id = $c->validation->param('patron_id');
    my $patron    = Koha::Patrons->find( $patron_id );

    unless ($patron) {
         return $c->render(
             status  => 404,
             openapi => { error => "Patron not found" }
         );
     }

    return try {
        my $body = $c->validation->param('body');
        my $user = $c->stash('koha.user');

        if (
                $patron->is_superlibrarian
            and !$user->is_superlibrarian
            and (  exists $body->{email}
                or exists $body->{secondary_email}
                or exists $body->{altaddress_email} )
          )
        {
            foreach my $email_field ( qw(email secondary_email altaddress_email) ) {
                my $exists_email = exists $body->{$email_field};
                next unless $exists_email;

                # exists, verify if we are asked to change it
                my $put_email      = $body->{$email_field};
                # As of writing this patch, 'email' is the only unmapped field
                # (i.e. it preserves its name, hence this fallback)
                my $db_email_field = $patron->to_api_mapping->{$email_field} // 'email';
                my $db_email       = $patron->$db_email_field;

                return $c->render(
                    status  => 403,
                    openapi => { error => "Not enough privileges to change a superlibrarian's email" }
                  )
                  unless ( !defined $put_email and !defined $db_email )
                  or (  defined $put_email
                    and defined $db_email
                    and $put_email eq $db_email );
            }
        }

        $patron->set_from_api($c->validation->param('body'))->store;
        $patron->discard_changes;
        return $c->render( status => 200, openapi => $patron->to_api );
    }
    catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => {
                    error => "Something went wrong, check Koha logs for details."
                }
            );
        }
        if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => $_->error, conflict => $_->duplicate_id }
            );
        }
        elsif ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
            return $c->render(
                status  => 400,
                openapi => { error => "Given " .
                            $patron->to_api_mapping->{$_->broken_fk}
                            . " does not exist" }
            );
        }
        elsif ( $_->isa('Koha::Exceptions::MissingParameter') ) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => "Missing mandatory parameter(s)",
                    parameters => $_->parameter
                }
            );
        }
        elsif ( $_->isa('Koha::Exceptions::BadParameter') ) {
            return $c->render(
                status  => 400,
                openapi => {
                    error      => "Invalid parameter(s)",
                    parameters => $_->parameter
                }
            );
        }
        elsif ( $_->isa('Koha::Exceptions::NoChanges') ) {
            return $c->render(
                status  => 204,
                openapi => { error => "No changes have been made" }
            );
        }
        else {
            $c->unhandled_exception($_);
        }
    };
}

=head3 delete

Controller function that handles deleting a Koha::Patron object

=cut

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $patron = Koha::Patrons->find( $c->validation->param('patron_id') );

    unless ( $patron ) {
        return $c->render(
            status  => 404,
            openapi => { error => "Patron not found" }
        );
    }

    return try {

        my $safe_to_delete = $patron->safe_to_delete;

        if ( !$safe_to_delete ) {
            # Pick the first error, if any
            my ( $error ) = grep { $_->type eq 'error' } @{ $safe_to_delete->messages };
            unless ( $error ) {
                Koha::Exception->throw('Koha::Patron->safe_to_delete returned false but carried no error message');
            }

            my $error_descriptions = {
                has_checkouts  => 'Pending checkouts prevent deletion',
                has_debt       => 'Pending debts prevent deletion',
                has_guarantees => 'Patron is a guarantor and it prevents deletion',
                is_anonymous_patron => 'Anonymous patron cannot be deleted',
            };

            if ( any { $error->message eq $_ } keys %{$error_descriptions} ) {
                return $c->render(
                    status  => 409,
                    openapi => {
                        error      => $error_descriptions->{ $error->message },
                        error_code => $error->message,
                    }
                );
            } else {
                Koha::Exception->throw( 'Koha::Patron->safe_to_delete carried an unexpected message: ' . $error->message );
            }
        }

        return $patron->_result->result_source->schema->txn_do(
            sub {
                $patron->move_to_deleted;
                $patron->delete;

                return $c->render(
                    status  => 204,
                    openapi => q{}
                );
            }
        );
    } catch {

        $c->unhandled_exception($_);
    };
}

=head3 guarantors_can_see_charges

Method for setting whether guarantors can see the patron's charges.

=cut

sub guarantors_can_see_charges {
    my $c = shift->openapi->valid_input or return;

    return try {
        $c->auth->public( $c->param('patron_id') );

        if ( C4::Context->preference('AllowPatronToSetFinesVisibilityForGuarantor') ) {
            my $patron = $c->stash( 'koha.user' );
            my $privacy_setting = ($c->req->json->{allowed}) ? 1 : 0;

            $patron->privacy_guarantor_fines( $privacy_setting )->store;

            return $c->render(
                status  => 200,
                openapi => {}
            );
        }
        else {
            return $c->render(
                status  => 403,
                openapi => {
                    error =>
                      'The current configuration doesn\'t allow the requested action.'
                }
            );
        }
    }
    catch {
        $c->unhandled_exception($_);
    };
}

=head3 guarantors_can_see_checkouts

Method for setting whether guarantors can see the patron's checkouts.

=cut

sub guarantors_can_see_checkouts {
    my $c = shift->openapi->valid_input or return;

    return try {
        $c->auth->public( $c->param('patron_id') );

        if ( C4::Context->preference('AllowPatronToSetCheckoutsVisibilityForGuarantor') ) {
            my $patron = $c->stash( 'koha.user' );
            my $privacy_setting = ( $c->req->json->{allowed} ) ? 1 : 0;

            $patron->privacy_guarantor_checkouts( $privacy_setting )->store;

            return $c->render(
                status  => 200,
                openapi => {}
            );
        }
        else {
            return $c->render(
                status  => 403,
                openapi => {
                    error =>
                      'The current configuration doesn\'t allow the requested action.'
                }
            );
        }
    }
    catch {
        $c->unhandled_exception($_);
    };
}

1;
