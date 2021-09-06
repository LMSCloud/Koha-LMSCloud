package Koha::Plugin::Test;

## It's good practice to use Modern::Perl
use Modern::Perl;

use Koha::Exceptions::Exception;
use Koha::Plugins::Tab;

use Mojo::JSON qw(decode_json);

## Required for all plugins
use base qw(Koha::Plugins::Base);

our $VERSION = 1.01;
our $metadata = {
    name            => 'Test Plugin',
    author          => 'Kyle M Hall',
    description     => 'Test plugin',
    date_authored   => '2013-01-14',
    date_updated    => '2013-01-14',
    minimum_version => '3.11',
    maximum_version => undef,
    version         => $VERSION,
    my_example_tag  => 'find_me',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub report {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::report";
}

sub tool {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::tool";
}

sub to_marc {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::to_marc";
}

sub intranet_catalog_biblio_enhancements_toolbar_button {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::intranet_catalog_biblio_enhancements_toolbar_button";
}

sub intranet_catalog_biblio_enhancements {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::intranet_catalog_biblio_enhancements";
}

sub opac_online_payment {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::opac_online_payment";
}

sub opac_online_payment_begin {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::opac_online_payment_begin";
}

sub opac_online_payment_end {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::opac_online_payment_end";
}

sub opac_head {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::opac_head";
}

sub opac_js {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::opac_js";
}

sub intranet_head {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::intranet_head";
}

sub intranet_js {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::intranet_js";
}

sub configure {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::configure";;
}

sub install {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::install";
}

sub upgrade {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::upgrade";
}

sub uninstall {
    my ( $self, $args ) = @_;
    return "Koha::Plugin::Test::uninstall";
}

sub test_output {
    my ( $self ) = @_;
    $self->output( '¡Hola output!', 'json' );
}

sub test_output_html {
    my ( $self ) = @_;
    $self->output_html( '¡Hola output_html!' );
}

sub api_namespace {
    return "testplugin";
}

sub after_hold_create {
    my ( $self, $param ) = @_;
    Koha::Exceptions::Exception->throw("after_hold_create called with parameter " . ref($param) );
}

sub after_biblio_action {
    my ( $self, $params ) = @_;
    my $action    = $params->{action} // '';
    my $biblio    = $params->{biblio};
    my $biblio_id = $params->{biblio_id};

    if ( $action ne 'delete' ) {
        Koha::Exceptions::Exception->throw("after_biblio_action called with action: $action, ref: " . ref($biblio) );
    }
    else {
        Koha::Exceptions::Exception->throw("after_biblio_action called with action: $action") if $biblio_id;
    }
}

sub after_item_action {
    my ( $self, $params ) = @_;
    my $action  = $params->{action} // '';
    my $item    = $params->{item};
    my $item_id = $params->{item_id};

    if ( $action ne 'delete' ) {
        my $itemnumber_defined = (defined $item->itemnumber) ? 'yes' : 'no';
        my $item_id_defined    = (defined $item_id) ? 'yes' : 'no';
        Koha::Exceptions::Exception->throw("after_item_action called with action: $action, ref: " . ref($item) . " ".
                                           "item_id defined: $item_id_defined ".
                                           "itemnumber defined: $itemnumber_defined" );
    }
    else {
        Koha::Exceptions::Exception->throw("after_item_action called with action: $action" ) if $item_id;
    }
}

sub after_circ_action {
    my ( $self, $params ) = @_;

    my $action   = $params->{action};
    my $checkout = $params->{payload}->{checkout};
    my $payload  = $params->{payload};

    my $type = $payload->{type};

    if ( $action eq 'renewal' ) {
        Koha::Exceptions::Exception->throw("after_circ_action called with action: $action, ref: " . ref($checkout));
    }
    elsif ( $action eq 'checkout') {
        Koha::Exceptions::Exception->throw("after_circ_action called with action: $action, ref: " . ref($checkout) . " type: $type");
    }
    elsif ( $action eq 'checkin' ) {
        Koha::Exceptions::Exception->throw("after_circ_action called with action: $action, ref: " . ref($checkout));
    }
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec = qq{
{
  "/patrons/bother": {
    "get": {
      "x-mojo-to": "Test::Controller#bother",
      "operationId": "BotherPatron",
      "tags": ["patrons"],
      "produces": [
        "application/json"
      ],
      "responses": {
        "200": {
          "description": "A bothered patron",
          "schema": {
              "type": "object",
                "properties": {
                  "bothered": {
                    "description": "If the patron has been bothered",
                    "type": "boolean"
                  }
                }
          }
        },
        "401": {
          "description": "An error occurred",
          "schema": {
              "type": "object",
              "properties": {
                "error": {
                  "description": "An explanation for the error",
                  "type": "string"
                }
              }
          }
        }
      },
      "x-koha-authorization": {
        "permissions": {
          "borrowers": "1"
        }
      }
    }
  },
  "/public/patrons/bother": {
    "get": {
      "x-mojo-to": "Test::Controller#bother",
      "operationId": "PubliclyBotherPatron",
      "tags": ["patrons"],
      "produces": [
        "application/json"
      ],
      "responses": {
        "200": {
          "description": "A bothered patron",
          "schema": {
              "type": "object",
              "properties": {
                "bothered": {
                  "description": "If the patron has been bothered",
                  "type": "boolean"
                }
              }
          }
        },
        "401": {
          "description": "Authentication required",
          "schema": {
            "type": "object",
            "properties": {
              "error": {
                "description": "An explanation for the error",
                "type": "string"
              }
            }
          }
        }
      }
    }
  }
}
    };

    return decode_json($spec);
}

sub check_password {
    my ( $self, $args ) = @_;

    my $password = $args->{'password'};
    if ( $password && $password =~ m/^\d{4}$/ ) {
        return { error => 0 };
    }
    else {
        return {
            error => 1,
            msg   => "PIN should be four digits"
        };
    }
}

sub intranet_catalog_biblio_tab {
    my @tabs;
    push @tabs,
      Koha::Plugins::Tab->new(
        {
            title   => 'Tab 1',
            content => 'This is content for tab 1'
        }
      );

    push @tabs,
      Koha::Plugins::Tab->new(
        {
            title   => 'Tab 2',
            content => 'This is content for tab 2'
        }
      );

    return @tabs;
}

sub _private_sub {
    return "";
}

1;
