package Koha::REST::V1::BZSH::ExternalOrder;

# Copyright 2019 LMSCloud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Carp;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

use Scalar::Util qw(blessed);
use Try::Tiny;
use DateTime::Format::W3CDTF;
use DateTime::Format::MySQL;

use Koha::Patron;
use Koha::Patrons;
use Koha::Library;
use Koha::Libraries;
use Koha::ExternalOrder;
use Koha::ExternalOrders;

use C4::Biblio qw(GetMarcBiblio);
use C4::Context;

use LWP::UserAgent;

=head1 NAME

Koha::REST::V1::ExternalOrder

=head1 API

=head2 Methods


=head3 add

Controller function that handles external aquisition order requests.

=cut

sub addExternalOrder {
    
    my $argvalue = shift;
    my $c = $argvalue->openapi->valid_input or return;
    my $apiparams = $c->req->json;

    return try {
        my ($responsecode, $responsetext) = &handleBZSHExternalOrderRequest($apiparams);
        return $c->render( status => $responsecode, openapi => { process_info => $responsetext } );
    }
    catch {
        unless ( blessed $_ && $_->can('rethrow') ) {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
        if ( $_->isa('Koha::Exceptions::Object::DuplicateID') ) {
            return $c->render(
                status  => 409,
                openapi => { error => $_->error, conflict => $_->duplicate_id }
            );
        }
        else {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check Koha logs for details." }
            );
        }
    };
}

    
sub handleBZSHExternalOrderRequest {
    my $orderReqest = shift;
    
    my $respcode = '200';
    my $resptext = 'External order successfully stored for further processing.';
    my @errors = ();
    my $ordertime;
    
    # $VAR1 = {
          # 'external_order_id' => 'abc1234',
          # 'order_time' => '2020-01-12T19:20:30.45+01:00',
          # 'order_type' => 'SHOP',
          # 'order_items' => [
                           # {
                             # 'biblionumber' => 32141,
                             # 'price' => '12.9',
                             # 'external_biblionumber' => '12',
                             # 'copies' => 1,
                             # 'supply_options' => [
                                                 # 'foiled'
                                               # ]
                           # }
                         # ],
          # 'patron_id' => 12,
          # 'library_id' => '151'
        # };

    # check patron
    if ( $orderReqest && exists($orderReqest->{patron_id}) ) {
        my $patron = Koha::Patrons->find( $orderReqest->{patron_id} );
        push @errors, 'Patron ID ' . $orderReqest->{patron_id} . ' is invalid.' if (! $patron );
    } else {
        push @errors, 'Patron ID is missing.';
    }
    
    # check branch library id
    if ( $orderReqest && exists($orderReqest->{library_id}) ) {
        my $library = Koha::Libraries->find( $orderReqest->{library_id} );
        push @errors, 'Library ID ' . $orderReqest->{library_id} . ' is invalid.' if (! $library );
    } else {
        push @errors, 'Library ID is missing.';
    }
    
    # check order_type + external_order_id filled and uniq in table external_orders
    if ( $orderReqest && exists($orderReqest->{external_order_id}) && exists($orderReqest->{order_type}) 
         && $orderReqest->{external_order_id} && $orderReqest->{order_type} ) 
    {
        my $orders = Koha::ExternalOrders->search( {
                                                        external_order_id => $orderReqest->{external_order_id},
                                                        order_type        => $orderReqest->{order_type}
                                                    } );
        push @errors, 'External order ID with order type already exists.' if ( $orders->count );
    } else {
        push @errors, 'External order ID or order type is missing.';
    }
    
    # check order time
    if ( $orderReqest && exists($orderReqest->{order_time}) ) {
        eval { $ordertime = DateTime::Format::W3CDTF->new()->parse_datetime($orderReqest->{order_time}); };

        push @errors, 'Order time ' . $orderReqest->{order_time} . ' is invalid.' if (! $ordertime );
    } else {
        push @errors, 'Order time not specified.';
    }
    
    # check count(order_items) > 0
    if ( $orderReqest && exists($orderReqest->{order_items}) ) {
        push @errors, 'No order items provided.' if (! scalar( @{$orderReqest->{order_items}} ) );
        
        # check order_items
        my $i=0;
        foreach my $orderItem( @{$orderReqest->{order_items}} ) {
            $i++;
            
            # check biblionumber of order item
            if ( $orderItem && exists($orderItem->{biblionumber}) ) {
                my $record = GetMarcBiblio( { biblionumber => $orderItem->{biblionumber} } );
                push @errors, "Bibliographic record with ID " . $orderItem->{biblionumber} . " of order item $i does not exist." if ( ! $record );
            } else {
                push @errors, "Bibliographic record for order item $i is missing.";
            }
            
            # check count of copies  of order item > 0
            if ( $orderItem && exists($orderItem->{copies}) ) {
                push @errors, "Count of copies value " . $orderItem->{copies} . " is not correct for order item $i." if ( $orderItem->{copies} !~ /^[0-9]+$/ || $orderItem->{copies} <= 0 );
            } else {
                push @errors, "Count of copies is not specified for order item $i.";
            }
        
            # check price of order items >= 0.0
            if ( $orderItem && exists($orderItem->{price}) ) {
                push @errors, "Price value " . $orderItem->{price} . " is not correct for order item $i." if ( $orderItem->{price} !~ /^[0-9]+(\.[0-9]+)?$/ || $orderItem->{price} < 0.0 );
            } else {
                push @errors, "Price value not specified for order item $i.";
            }
        }
    } else {
        push @errors, 'No order items provided.';
    }
    

    
    print STDERR Dumper($orderReqest);
    
    if ( scalar(@errors) ) {
        $respcode = '400';
        $resptext = join(" ",@errors);
    } else {
        my $newOrder = {
                            branchcode         => $orderReqest->{library_id},
                            borrowernumber     => $orderReqest->{patron_id},
                            external_order_id  => $orderReqest->{external_order_id},
                            order_type         => $orderReqest->{order_type},
                            order_time         => DateTime::Format::MySQL->format_datetime($ordertime),
                            order_data         => JSON->new->utf8->pretty(1)->encode($orderReqest)
                       };
       my $externalOrder = Koha::ExternalOrder->new($newOrder)->store;
       
       if ( $externalOrder ) {
           # $externalOrder->id is the new id
           if ( C4::Context->preference("ExternalOrderProcessingCommand") ) {
               my $externalOrderId = $externalOrder->id;
               my $cmd = C4::Context->preference("ExternalOrderProcessingCommand");
               system($cmd, "-id $externalOrderId");
           }
           if ( C4::Context->preference("ExternalOrderProcessingService") ) {
               my $externalOrderId = $externalOrder->id;
               my $service = C4::Context->preference("ExternalOrderProcessingService");
               $service .= "id=$externalOrderId";
               my $userAgent = LWP::UserAgent->new( timeout => 10 );
               my $resp = $userAgent->get($service);

               if (! $resp->is_success ) {
                   carp "Error calling external service '$service' to launch external order processing od external order id $externalOrderId. Call returned code " . $resp->code . " with response '" . $resp->as_string . "'";
               }
           }
       } else {
           $respcode = '400';
           $resptext = 'Error while saving new order request.';
       }
    }
    
    return ($respcode,$resptext);
}

1;