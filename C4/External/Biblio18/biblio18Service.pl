#!/usr/bin/env perl

use Modern::Perl;
use Mojolicious::Lite;

use File::Basename qw( dirname );
use Config::Simple;
use Carp;
use C4::External::Biblio18::Biblio18;
use JSON::XS;
use Encode qw/decode_utf8/;


my $config = initialize();

helper biblioservice => sub { state $service = C4::External::Biblio18::Biblio18->new($config->{service}); };
helper json => sub { state $json = JSON::XS->new->utf8(1)->canonical(1)->pretty(1); };
helper jsonlog => sub { state $json = JSON::XS->new->utf8(1)->canonical(1); };
helper logger => sub { state $logger = Mojo::Log->new(path => $config->{logger}->{'log_file'}, level => $config->{logger}->{'log_level'}); };

get  '/version' => sub { 
                            my $c = shift;
                            
                            my $ip = $c->tx->original_remote_address || '';
                            my $agent = $c->tx->req->content->headers->user_agent || '';
                            my $rid = $c->req->request_id;
                                
                            $c->logger->info("request($rid):$ip($agent) => version request");
                            
                            if ( checkAuthentication($c) ) {
                                $c->render(json => $c->biblioservice->getVersion()); 
                            }
                       };
post  '/extauth' => sub { 
                            my $c = shift; 
                            
                            my $data = $c->req->json;
                            my $ip = $c->tx->original_remote_address || '';
                            my $agent = $c->tx->req->content->headers->user_agent || '';
                            my $rid = $c->req->request_id;
                            
                            $c->logger->info("request($rid):$ip($agent) => extauth request: " . $c->jsonlog->encode($data) );
                            
                            if ( checkAuthentication($c) ) {
                                my ($response,$error) = $c->biblioservice->authenticatePatron($data);
                                
                                if ( $error ) {
                                    $c->logger->error("request($rid):$ip($agent) => extauth error: $error");
                                    $c->render(text => "Patron not found.", status => '404');
                                } else {
                                    $c->logger->info("request($rid):$ip($agent) => extauth result: " . $c->jsonlog->encode($response) );
                                    $c->render(text => decode_utf8($c->json->encode($response)), format => 'json' );
                                }
                            }
                       };
get  '/search' => sub { 
                            my $c = shift; 
                            
                            my $query = $c->param('searchValue') || '';
                            my $checkAvailDays = $c->param('checkAvailDays') || '';
                                
                            my $ip = $c->tx->original_remote_address || '';
                            my $agent = $c->tx->req->content->headers->user_agent || '';
                            my $rid = $c->req->request_id;
                            $c->logger->info("request($rid):$ip($agent) => search request: query($query), checkAvailDays($checkAvailDays)");
                            
                            if ( checkAuthentication($c) ) {
                                my $searchresult = $c->biblioservice->search($query,$checkAvailDays);
                                $c->logger->info("request($rid):$ip($agent) => search result: found " . scalar(@{$searchresult->{CatalogItems}}) . " result records" );
                                $c->render(text => decode_utf8($c->json->encode($searchresult)), format => 'json' ); 
                            }
                       };


app->config(hypnotoad => $config->{hypnotoad} );

app->start();
# app->start('daemon', '-m', 'production', '-l', 'http://*:5800');


# curl -u "user:password" -X GET --header 'Accept: application/json' 'http://localhost:5800/version'
# curl -u "user:password" -X GET --header 'Accept: application/json' 'http://localhost:5800/search?searchValue=wunder'
# curl -u "user:password" -X POST --header 'Accept: application/json' -d '{"barcodeOrAlias":"yyy","pwd":"xxxx","getname":true}' 'http://localhost:5800/extauth'



sub checkAuthentication {
    my $c = shift;
    
    my $userinfo = $c->req->url->to_abs->userinfo || '';
    my ($user,$password) = split(/:/,$userinfo,2);
    my $valid = $c->biblioservice->validateCredentials($user,$password);
    
    my $ip = $c->tx->original_remote_address || '';
    my $agent = $c->tx->req->content->headers->user_agent || '';
    my $rid = $c->req->request_id;
                                
    $c->logger->info("request($rid):$ip($agent) => authentication valid=$valid" );
    
    if (! $valid ) {
        $c->logger->error("request($rid):$ip($agent) => authentication failed with userinfo($userinfo)" );
        $c->render(text => "Authentication failed.", status => '401');
        return 0;
    }
    return 1;
}

sub initialize {
    # Initialize
    my $serviceconf = dirname($ENV{"KOHA_CONF"}) . '/Biblio18.conf';
    croak "Biblio18 service configuration file $serviceconf not found" if (! -e $serviceconf || ! -f $serviceconf);
    croak "Biblio18 service configuration file $serviceconf not readable" if (! -r $serviceconf);

    my $configuration = new Config::Simple("$serviceconf"); 
    my %Config = $configuration->vars();
    my $hypnotoadConfig = {};
    my $serviceConfig = {};
    my $logger = {};
    foreach my $configEntry (keys %Config) {
        if ( $configEntry =~ /^hypnotoad\.(.+)$/ ) {
            if ( $1 eq 'listen' ) {
                $hypnotoadConfig->{$1} = [$Config{$configEntry}];
            } else {
                $hypnotoadConfig->{$1} = $Config{$configEntry};
            }
        }
        elsif ( $configEntry =~ /^service\.(.+)$/ ) {
            $serviceConfig->{$1} = $configuration->param($configEntry);
        }
        elsif ( $configEntry =~ /^logger\.(.+)$/ ) {
            $logger->{$1} = $configuration->param($configEntry);
        }
    }
    return { hypnotoad => $hypnotoadConfig, service => $serviceConfig, logger => $logger };
}
