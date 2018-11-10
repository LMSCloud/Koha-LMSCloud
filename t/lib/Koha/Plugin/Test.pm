package Koha::Plugin::Test;

## It's good practice to use Modern::Perl
use Modern::Perl;

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

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec = qq{
{
  "/patrons/{patron_id}/bother": {
    "put": {
      "x-mojo-to": "Koha::Plugin::Test#bother",
      "operationId": "BotherPatron",
      "tags": ["patrons"],
      "parameters": [{
        "name": "patron_id",
        "in": "path",
        "description": "Internal patron identifier",
        "required": true,
        "type": "integer"
      }],
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
        "404": {
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
  }
}
    };

    return decode_json($spec);
}
