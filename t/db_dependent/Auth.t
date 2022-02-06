#!/usr/bin/perl
#
# This Koha test module is a stub!  
# Add more tests here!!!

use Modern::Perl;

use CGI qw ( -utf8 );

use Test::MockObject;
use Test::MockModule;
use List::MoreUtils qw/all any none/;
use Test::More tests => 24;
use Test::Warn;
use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Auth qw(checkpw);
use C4::Members;
use Koha::AuthUtils qw/hash_password/;
use Koha::Database;
use Koha::Patrons;

BEGIN {
    use_ok('C4::Auth');
}

my $schema  = Koha::Database->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

# FIXME: SessionStorage defaults to mysql, but it seems to break transaction
# handling
t::lib::Mocks::mock_preference( 'SessionStorage', 'tmp' );
t::lib::Mocks::mock_preference( 'GDPR_Policy', '' ); # Disabled

$schema->storage->txn_begin;

subtest 'checkauth() tests' => sub {

    plan tests => 4;

    my $patron = $builder->build_object({ class => 'Koha::Patrons', value => { flags => undef } });

    # Mock a CGI object with real userid param
    my $cgi = Test::MockObject->new();
    $cgi->mock(
        'param',
        sub {
            my $var = shift;
            if ( $var eq 'userid' ) { return $patron->userid; }
        }
    );
    $cgi->mock( 'cookie', sub { return; } );
    $cgi->mock( 'request_method', sub { return 'POST' } );

    my $authnotrequired = 1;
    my ( $userid, $cookie, $sessionID, $flags ) = C4::Auth::checkauth( $cgi, $authnotrequired );

    is( $userid, undef, 'checkauth() returns undef for userid if no logged in user (Bug 18275)' );

    my $db_user_id = C4::Context->config('user');
    my $db_user_pass = C4::Context->config('pass');
    $cgi = Test::MockObject->new();
    $cgi->mock( 'cookie', sub { return; } );
    $cgi->mock( 'param', sub {
            my ( $self, $param ) = @_;
            if ( $param eq 'userid' ) { return $db_user_id; }
            elsif ( $param eq 'password' ) { return $db_user_pass; }
            else { return; }
        });
    $cgi->mock( 'request_method', sub { return 'POST' } );
    ( $userid, $cookie, $sessionID, $flags ) = C4::Auth::checkauth( $cgi, $authnotrequired );
    is ( $userid, undef, 'If DB user is used, it should not be logged in' );

    my $is_allowed = C4::Auth::haspermission( $db_user_id, { can_do => 'everything' } );

    # FIXME This belongs to t/db_dependent/Auth/haspermission.t but we do not want to c/p the pervious mock statements
    ok( !$is_allowed, 'DB user should not have any permissions');

    subtest 'Prevent authentication when sending credential via GET' => sub {

        plan tests => 2;

        my $patron = $builder->build_object(
            { class => 'Koha::Patrons', value => { flags => 1 } } );
        my $password = 'password';
        t::lib::Mocks::mock_preference( 'RequireStrongPassword', 0 );
        $patron->set_password( { password => $password } );
        $cgi = Test::MockObject->new();
        $cgi->mock( 'cookie', sub { return; } );
        $cgi->mock(
            'param',
            sub {
                my ( $self, $param ) = @_;
                if    ( $param eq 'userid' )   { return $patron->userid; }
                elsif ( $param eq 'password' ) { return $password; }
                else                           { return; }
            }
        );

        $cgi->mock( 'request_method', sub { return 'POST' } );
        ( $userid, $cookie, $sessionID, $flags ) = C4::Auth::checkauth( $cgi, 'authrequired' );
        is( $userid, $patron->userid, 'If librarian user is used and password with POST, they should be logged in' );

        $cgi->mock( 'request_method', sub { return 'GET' } );
        ( $userid, $cookie, $sessionID, $flags ) = C4::Auth::checkauth( $cgi, 'authrequired' );
        is( $userid, undef, 'If librarian user is used and password with GET, they should not be logged in' );
    };

    C4::Context->_new_userenv; # For next tests

};

subtest 'track_login_daily tests' => sub {

    plan tests => 5;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    my $userid = $patron->userid;

    $patron->lastseen( undef );
    $patron->store();

    my $cache     = Koha::Caches->get_instance();
    my $cache_key = "track_login_" . $patron->userid;
    $cache->clear_from_cache($cache_key);

    t::lib::Mocks::mock_preference( 'TrackLastPatronActivity', '1' );

    is( $patron->lastseen, undef, 'Patron should have not last seen when newly created' );

    C4::Auth::track_login_daily( $userid );
    $patron->_result()->discard_changes();
    isnt( $patron->lastseen, undef, 'Patron should have last seen set when TrackLastPatronActivity = 1' );

    sleep(1); # We need to wait a tiny bit to make sure the timestamp will be different
    my $last_seen = $patron->lastseen;
    C4::Auth::track_login_daily( $userid );
    $patron->_result()->discard_changes();
    is( $patron->lastseen, $last_seen, 'Patron last seen should still be unchanged' );

    $cache->clear_from_cache($cache_key);
    C4::Auth::track_login_daily( $userid );
    $patron->_result()->discard_changes();
    isnt( $patron->lastseen, $last_seen, 'Patron last seen should be changed if we cleared the cache' );

    t::lib::Mocks::mock_preference( 'TrackLastPatronActivity', '0' );
    $patron->lastseen( undef )->store;
    $cache->clear_from_cache($cache_key);
    C4::Auth::track_login_daily( $userid );
    $patron->_result()->discard_changes();
    is( $patron->lastseen, undef, 'Patron should still have last seen unchanged when TrackLastPatronActivity = 0' );

};

subtest 'no_set_userenv parameter tests' => sub {

    plan tests => 7;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $password = 'password';

    t::lib::Mocks::mock_preference( 'RequireStrongPassword', 0 );
    $patron->set_password({ password => $password });

    ok( checkpw( $dbh, $patron->userid, $password, undef, undef, 1 ), 'checkpw returns true' );
    is( C4::Context->userenv, undef, 'Userenv should be undef as required' );
    C4::Context->_new_userenv('DUMMY SESSION');
    C4::Context->set_userenv(0,0,0,'firstname','surname', $library->branchcode, 'Library 1', 0, '', '');
    is( C4::Context->userenv->{branch}, $library->branchcode, 'Userenv gives correct branch' );
    ok( checkpw( $dbh, $patron->userid, $password, undef, undef, 1 ), 'checkpw returns true' );
    is( C4::Context->userenv->{branch}, $library->branchcode, 'Userenv branch is preserved if no_set_userenv is true' );
    ok( checkpw( $dbh, $patron->userid, $password, undef, undef, 0 ), 'checkpw still returns true' );
    isnt( C4::Context->userenv->{branch}, $library->branchcode, 'Userenv branch is overwritten if no_set_userenv is false' );
};

subtest 'checkpw lockout tests' => sub {

    plan tests => 5;

    my $library = $builder->build_object( { class => 'Koha::Libraries' } );
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
    my $password = 'password';
    t::lib::Mocks::mock_preference( 'RequireStrongPassword', 0 );
    t::lib::Mocks::mock_preference( 'FailedLoginAttempts', 1 );
    $patron->set_password({ password => $password });

    my ( $checkpw, undef, undef ) = checkpw( $dbh, $patron->cardnumber, $password, undef, undef, 1 );
    ok( $checkpw, 'checkpw returns true with right password when logging in via cardnumber' );
    ( $checkpw, undef, undef ) = checkpw( $dbh, $patron->userid, "wrong_password", undef, undef, 1 );
    is( $checkpw, 0, 'checkpw returns false when given wrong password' );
    $patron = $patron->get_from_storage;
    is( $patron->account_locked, 1, "Account is locked from failed login");
    ( $checkpw, undef, undef ) = checkpw( $dbh, $patron->userid, $password, undef, undef, 1 );
    is( $checkpw, undef, 'checkpw returns undef with right password when account locked' );
    ( $checkpw, undef, undef ) = checkpw( $dbh, $patron->cardnumber, $password, undef, undef, 1 );
    is( $checkpw, undef, 'checkpw returns undefwith right password when logging in via cardnumber if account locked' );

};

# get_template_and_user tests

{   # Tests for the language URL parameter

    sub MockedCheckauth {
        my ($query,$authnotrequired,$flagsrequired,$type) = @_;
        # return vars
        my $userid = 'cobain';
        my $sessionID = 234;
        # we don't need to bother about permissions for this test
        my $flags = {
            superlibrarian    => 1, acquisition       => 0,
            borrowers         => 0,
            catalogue         => 1, circulate         => 0,
            coursereserves    => 0, editauthorities   => 0,
            editcatalogue     => 0,
            parameters        => 0, permissions       => 0,
            plugins           => 0, reports           => 0,
            reserveforothers  => 0, serials           => 0,
            staffaccess       => 0, tools             => 0,
            updatecharges     => 0
        };

        my $session_cookie = $query->cookie(
            -name => 'CGISESSID',
            -value    => 'nirvana',
            -HttpOnly => 1
        );

        return ( $userid, $session_cookie, $sessionID, $flags );
    }

    # Mock checkauth, build the scenario
    my $auth = Test::MockModule->new( 'C4::Auth' );
    $auth->mock( 'checkauth', \&MockedCheckauth );

    # Make sure 'EnableOpacSearchHistory' is set
    t::lib::Mocks::mock_preference('EnableOpacSearchHistory',1);
    # Enable es-ES for the OPAC and staff interfaces
    t::lib::Mocks::mock_preference('OPACLanguages','en,es-ES');
    t::lib::Mocks::mock_preference('language','en,es-ES');

    # we need a session cookie
    $ENV{"SERVER_PORT"} = 80;
    $ENV{"HTTP_COOKIE"} = 'CGISESSID=nirvana';

    my $query = CGI->new;
    $query->param('language','es-ES');

    my ( $template, $loggedinuser, $cookies ) = get_template_and_user(
        {
            template_name   => "about.tt",
            query           => $query,
            type            => "opac",
            authnotrequired => 1,
            flagsrequired   => { catalogue => 1 },
            debug           => 1
        }
    );

    ok ( ( all { ref($_) eq 'CGI::Cookie' } @$cookies ),
            'BZ9735: the cookies array is flat' );

    # new query, with non-existent language (we only have en and es-ES)
    $query->param('language','tomas');

    ( $template, $loggedinuser, $cookies ) = get_template_and_user(
        {
            template_name   => "about.tt",
            query           => $query,
            type            => "opac",
            authnotrequired => 1,
            flagsrequired   => { catalogue => 1 },
            debug           => 1
        }
    );

    ok( ( none { $_->name eq 'KohaOpacLanguage' and $_->value eq 'tomas' } @$cookies ),
        'BZ9735: invalid language, it is not set');

    ok( ( any { $_->name eq 'KohaOpacLanguage' and $_->value eq 'en' } @$cookies ),
        'BZ9735: invalid language, then default to en');

    for my $template_name (
        qw(
            ../../../../../../../../../../../../../../../etc/passwd
            test/../../../../../../../../../../../../../../etc/passwd
            /etc/passwd
            test/does_not_finished_by_tt_t
        )
    ) {
        eval {
            ( $template, $loggedinuser, $cookies ) = get_template_and_user(
                {
                    template_name   => $template_name,
                    query           => $query,
                    type            => "intranet",
                    authnotrequired => 1,
                    flagsrequired   => { catalogue => 1 },
                }
            );
        };
        like ( $@, qr(^bad template path), "The file $template_name should not be accessible" );
    }
    ( $template, $loggedinuser, $cookies ) = get_template_and_user(
        {
            template_name   => 'errors/errorpage.tt',
            query           => $query,
            type            => "intranet",
            authnotrequired => 1,
            flagsrequired   => { catalogue => 1 },
        }
    );
    my $file_exists = ( -f $template->{filename} ) ? 1 : 0;
    is ( $file_exists, 1, 'The file errors/errorpage.tt should be accessible (contains integers)' );

    # Regression test for env opac search limit override
    $ENV{"OPAC_SEARCH_LIMIT"} = "branch:CPL";
    $ENV{"OPAC_LIMIT_OVERRIDE"} = 1;

    ( $template, $loggedinuser, $cookies) = get_template_and_user(
        {
            template_name => 'opac-main.tt',
            query => $query,
            type => 'opac',
            authnotrequired => 1,
        }
    );
    is($template->{VARS}->{'opac_name'}, "CPL", "Opac name was set correctly");
    is($template->{VARS}->{'opac_search_limit'}, "branch:CPL", "Search limit was set correctly");

    $ENV{"OPAC_SEARCH_LIMIT"} = "branch:multibranch-19";

    ( $template, $loggedinuser, $cookies) = get_template_and_user(
        {
            template_name => 'opac-main.tt',
            query => $query,
            type => 'opac',
            authnotrequired => 1,
        }
    );
    is($template->{VARS}->{'opac_name'}, "multibranch-19", "Opac name was set correctly");
    is($template->{VARS}->{'opac_search_limit'}, "branch:multibranch-19", "Search limit was set correctly");
}

# Check that there is always an OPACBaseURL set.
my $input = CGI->new();
my ( $template1, $borrowernumber, $cookie );
( $template1, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => "opac-detail.tt",
        type => "opac",
        query => $input,
        authnotrequired => 1,
    }
);

ok( ( any { 'OPACBaseURL' eq $_ } keys %{$template1->{VARS}} ),
    'OPACBaseURL is in OPAC template' );

my ( $template2 );
( $template2, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => "catalogue/detail.tt",
        type => "intranet",
        query => $input,
        authnotrequired => 1,
    }
);

ok( ( any { 'OPACBaseURL' eq $_ } keys %{$template2->{VARS}} ),
    'OPACBaseURL is in Staff template' );

my $hash1 = hash_password('password');
my $hash2 = hash_password('password');

ok(C4::Auth::checkpw_hash('password', $hash1), 'password validates with first hash');
ok(C4::Auth::checkpw_hash('password', $hash2), 'password validates with second hash');

subtest 'Check value of login_attempts in checkpw' => sub {
    plan tests => 11;

    t::lib::Mocks::mock_preference('FailedLoginAttempts', 3);

    # Only interested here in regular login
    $C4::Auth::cas  = 0;
    $C4::Auth::ldap = 0;

    my $patron = $builder->build_object({ class => 'Koha::Patrons' });
    $patron->login_attempts(2);
    $patron->password('123')->store; # yes, deliberately not hashed

    is( $patron->account_locked, 0, 'Patron not locked' );
    my @test = checkpw( $dbh, $patron->userid, '123', undef, 'opac', 1 );
        # Note: 123 will not be hashed to 123 !
    is( $test[0], 0, 'checkpw should have failed' );
    $patron->discard_changes; # refresh
    is( $patron->login_attempts, 3, 'Login attempts increased' );
    is( $patron->account_locked, 1, 'Check locked status' );

    # And another try to go over the limit: different return value!
    @test = checkpw( $dbh, $patron->userid, '123', undef, 'opac', 1 );
    is( @test, 0, 'checkpw failed again and returns nothing now' );
    $patron->discard_changes; # refresh
    is( $patron->login_attempts, 3, 'Login attempts not increased anymore' );

    # Administrative lockout cannot be undone?
    # Pass the right password now (or: add a nice mock).
    my $auth = Test::MockModule->new( 'C4::Auth' );
    $auth->mock( 'checkpw_hash', sub { return 1; } ); # not for production :)
    $patron->login_attempts(0)->store;
    @test = checkpw( $dbh, $patron->userid, '123', undef, 'opac', 1 );
    is( $test[0], 1, 'Build confidence in the mock' );
    $patron->login_attempts(-1)->store;
    is( $patron->account_locked, 1, 'Check administrative lockout' );
    @test = checkpw( $dbh, $patron->userid, '123', undef, 'opac', 1 );
    is( @test, 0, 'checkpw gave red' );
    $patron->discard_changes; # refresh
    is( $patron->login_attempts, -1, 'Still locked out' );
    t::lib::Mocks::mock_preference('FailedLoginAttempts', ''); # disable
    is( $patron->account_locked, 1, 'Check administrative lockout without pref' );
};

subtest '_timeout_syspref' => sub {
    plan tests => 5;

    t::lib::Mocks::mock_preference('timeout', "100");
    is( C4::Auth::_timeout_syspref, 100, );

    t::lib::Mocks::mock_preference('timeout', "2d");
    is( C4::Auth::_timeout_syspref, 2*86400, );

    t::lib::Mocks::mock_preference('timeout', "2D");
    is( C4::Auth::_timeout_syspref, 2*86400, );

    t::lib::Mocks::mock_preference('timeout', "10h");
    is( C4::Auth::_timeout_syspref, 10*3600, );

    t::lib::Mocks::mock_preference('timeout', "10x");
    is( C4::Auth::_timeout_syspref, 600, );
};

subtest 'check_cookie_auth' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference('timeout', "1d"); # back to default

    my $patron = $builder->build_object({ class => 'Koha::Patrons', value => { flags => 1 } });

    # Mock a CGI object with real userid param
    my $cgi = Test::MockObject->new();
    $cgi->mock(
        'param',
        sub {
            my $var = shift;
            if ( $var eq 'userid' ) { return $patron->userid; }
        }
    );
    $cgi->mock('multi_param', sub {return q{}} );
    $cgi->mock( 'cookie', sub { return; } );
    $cgi->mock( 'request_method', sub { return 'POST' } );

    $ENV{REMOTE_ADDR} = '127.0.0.1';

    # Setting authnotrequired=1 or we wont' hit the return but the end of the sub that prints headers
    my ( $userid, $cookie, $sessionID, $flags ) = C4::Auth::checkauth( $cgi, 1 );

    my ($auth_status, $session) = C4::Auth::check_cookie_auth($sessionID);
    isnt( $auth_status, 'ok', 'check_cookie_auth should not return ok if the user has not been authenticated before if no permissions needed' );
    is( $auth_status, 'anon', 'check_cookie_auth should return anon if the user has not been authenticated before and no permissions needed' );

    ( $userid, $cookie, $sessionID, $flags ) = C4::Auth::checkauth( $cgi, 1 );

    ($auth_status, $session) = C4::Auth::check_cookie_auth($sessionID, {catalogue => 1});
    isnt( $auth_status, 'ok', 'check_cookie_auth should not return ok if the user has not been authenticated before and permissions needed' );
    is( $auth_status, 'anon', 'check_cookie_auth should return anon if the user has not been authenticated before and permissions needed' );

    #FIXME We should have a test to cover 'failed' status when a user has logged in, but doesn't have permission
};

$schema->storage->txn_rollback;
