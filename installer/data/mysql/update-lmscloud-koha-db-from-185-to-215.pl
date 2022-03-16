#!/usr/bin/perl

use Modern::Perl;
use utf8;

use Carp;
use DBI;
use Getopt::Long;
# Koha modules
use C4::Context;
use Koha::Config;
use Koha::SearchEngine::Elasticsearch;
use Text::Diff qw(diff);

# additional for epayment migration
use Archive::Extract;
use Mojo::UserAgent;
use File::Copy;
use File::Temp;
use Capture::Tiny;
use Koha::Plugins;
use Text::Diff qw(diff);


BEGIN{ $| = 1; }

binmode(STDIN, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $instance = getInstanceName();

updateKohaConfig($instance);
updateHiddenColumnsSettings();
updateSimpleVariables();
updateMoreSearchesContent();
updateEntryPages();
updateOverwrittenOPACBrowserTemplates($instance);
updateVariablesInNewsTexts();
updateSidebarLinks();
updateOPACUserJS();
rebuildElasticSearchIndex();
createSIPEnabledFile($instance);
updateIntranetMainUserBlock();
updateGermanLetterTemplates();
updateReports();

&migrate_epayment_to_2105('LMSC');
&migrate_epayment_to_2105('KohaPayPal');



############################################################################
#
#
# Functions for processing
#
#
############################################################################

sub getInstanceName {
    my $conf_fname = Koha::Config->guess_koha_conf;
    my $config = Koha::Config->read_from_file($conf_fname);
    if ( $conf_fname =~ m|^/etc/koha/sites/([^/]+)/| ) {
        return $1;
    }
    croak("Cannot determine the Koha instance name. Aborting processing.");
}

sub updateKohaConfig {
    my $instance = shift;
    my $conf_fname = Koha::Config->guess_koha_conf;
    my $config = Koha::Config->read_from_file($conf_fname);
    
    my $changed = 0;
    my $configtext;
    {
        local( $/ ); # undefine the record seperator
        open(my $rh,'<:encoding(UTF-8)', $conf_fname) or croak "Error opening $conf_fname: $!";
        $configtext = <$rh>;
        close $rh;
    }
    
    if ( exists( $config->{listen}->{publicserver}->{content} ) ) {
        if ( $config->{listen}->{publicserver}->{content} =~ /^\s*tcp:([^:]+):([0-9]+)\s*$/i ) {
            my $host = $1;
            my $port = $2;
            my $listenConfig = $config->{listen}->{publicserver}->{content};
            
            print "Configuring Z3950Responder from Zebra config: host ($host), port ($port)\n";
            
            $configtext =~ s/(\r?\n)(<listen\s+id="publicserver"[^>]*>.+?(?=\<\/listen>)<\/listen>)(\r?\n)/$1<!--$1$2$3-->$3/is;
            $changed = 1;
            
            if ( exists( $config->{server}->{publicserver} ) ) {
                $configtext =~ s/(\r?\n)(<server\s+id="publicserver"[^>]*>.+?(?=\<\/server>)<\/server>)(\r?\n)/$1<!--$1$2$3-->$3/is;
            }
            if ( exists( $config->{serverinfo}->{publicserver} ) ) {
                $configtext =~ s/(\r?\n)(<serverinfo\s+id="publicserver"[^>]*>.+?(?=\<\/serverinfo>)<\/serverinfo>)(\r?\n)/$1<!--$1$2$3-->$3/is;
            }
            
            my $needpermissions = 1;
            my $permissionadd = '';
            if ( exists( $config->{server}->{publicserver}->{config} ) ) {
                my $publicserverconfig = $config->{server}->{publicserver}->{config};
                my $serverconfigtext;
                {
                    local( $/ ); # undefine the record seperator
                    open(my $rh,'<:encoding(UTF-8)', $publicserverconfig) or carp "Error opening $publicserverconfig: $!";
                    $serverconfigtext = <$rh>;
                    close $rh;
                }
                my @permusers;
                if ( $serverconfigtext ) {
                    my $passwords = '';
                    if ( $serverconfigtext =~ /^passwd\s*:\s*(.+)$/m ) {
                        my $passwdfile = $1;
                        local( $/ ); # undefine the record seperator
                        open(my $rh,'<:encoding(UTF-8)', $passwdfile) or carp "Error opening $passwdfile: $!";
                        $passwords = <$rh>;
                        close $rh;
                    }
                    while ( $serverconfigtext =~ /^perm.([^: ]+)\s*:\s*([a-z]+)/mg ) {
                        my $permuser = $1;
                        my $permvalue = $2;
                        my $permpass = '';
                        
                        if ( $passwords =~ /^$permuser\s*:\s*(.+)$/m ) {
                            $permpass = $1;
                        }
                        if ( $permuser =~ /^anonymous$/ && $permvalue =~ /a/ && $permvalue =~ /r/ ) {
                            $needpermissions = 0;
                        }
                        push @permusers, {username => $permuser, password => $permpass} if ($permuser !~ /^anonymous$/);
                    }
                }
                
                $permissionadd = "  <permissions>\n    <validusers>\n";
                foreach my $permuser(@permusers) {
                    $permissionadd .= '      <user username="'. xmlEncode($permuser->{username}) .'" password="' . xmlEncode($permuser->{password}) .'"/>' ."\n";
                }
                $permissionadd .= "    </validusers>\n  </permissions>\n";
            }
            
            # now activate the new config
            system("koha-z3950-responder --enable $instance");
            
            # update config
            my $responderConfig = "/etc/koha/sites/$instance/z3950/config.xml";
            if ( -f $responderConfig ) {
                my $responderConfigText;
                {
                    local( $/ ); # undefine the record seperator
                    open(my $rh,'<:encoding(UTF-8)', $responderConfig) or carp "Error opening $responderConfig: $!";
                    $responderConfigText = <$rh>;
                    close $rh;
                }
                if ( $responderConfigText ) {
                    $responderConfigText =~ s/(<listen\s+id="public"[^>]*>).+?(?=\<\/listen>)(<\/listen>)/$1$listenConfig$2/is;
                    if ( $needpermissions && $permissionadd && $responderConfigText !~ /<permissions>/ ) {
                        $responderConfigText =~ s/(<\/server>\s*\r?\n)/$1$permissionadd/is;
                    }
                    {
                        my $backupfile = "$responderConfig.backup-".getLoggingTime();
                        copy($responderConfig,$backupfile);
                        print "Backup Z3950Responder config $responderConfig as $backupfile\n";
                        open(my $fh,'>:encoding(UTF-8)', $responderConfig) or carp "Error opening $responderConfig: $!";
                        print $fh $responderConfigText;
                        close $fh;
                        print "Updated Z3950Responder config $responderConfig\n";
                    }
                }
            }
        }
    }
    if (! exists( $config->{config}->{tls} ) ) {
        if ( exists( $config->{config}->{pass} ) ) {
            my $add =  ' <tls>__DB_USE_TLS__</tls>' . "\n" . 
                       ' <ca>__DB_TLS_CA_CERTIFICATE__</ca>' . "\n" . 
                       ' <cert>__DB_TLS_CLIENT_CERTIFICATE__</cert>' . "\n" . 
                       ' <key>__DB_TLS_CLIENT_KEY__</key>' . "\n";
            $configtext =~ s/(\r?\n *<pass>.+?(?=\<\/pass>)<\/pass> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if (! exists( $config->{config}->{mana_config} ) ) {
        if ( exists( $config->{config}->{backupdir} ) ) {
            my $add =  ' <!-- URL of the mana KB server -->' . "\n" . 
                       ' <!-- alternative value http://mana-test.koha-community.org to query the test server -->' . "\n" . 
                       ' <mana_config>https://mana-kb.koha-community.org</mana_config>' . "\n";
            $configtext =~ s/(\r?\n *<backupdir>.+?(?=\<\/backupdir>)<\/backupdir> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if (! exists( $config->{config}->{lockdir} ) ) {
        if ( exists( $config->{config}->{zebra_lockdir} ) ) {
            my $add =  ' <lockdir>/var/lock/koha/' . $instance . '</lockdir>' . "\n";
            $configtext =~ s/(\r?\n *<zebra_lockdir>.+?(?=\<\/zebra_lockdir>)<\/zebra_lockdir> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if (! exists( $config->{config}->{zebra_max_record_size} ) ) {
        if ( exists( $config->{config}->{use_zebra_facets} ) ) {
            my $add =  ' <zebra_max_record_size>1024</zebra_max_record_size>' . "\n";
            $configtext =~ s/(\r?\n *<use_zebra_facets>.+?(?=\<\/use_zebra_facets>)<\/use_zebra_facets> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if (! exists( $config->{config}->{access_dirs} ) && $configtext !~ /<access_dirs>/ ) {
        if ( exists( $config->{config}->{api_secret_passphrase} ) ) {
            my $add =  "\n" .
                       ' <!-- Accessible directory from the staff interface, uncomment the following line and define a valid path to let the intranet user access it-->' . "\n" .
                       ' <!--' . "\n" . 
                       ' <access_dirs>' . "\n" . 
                       '     <access_dir></access_dir>' . "\n" . 
                       '     <access_dir></access_dir>' . "\n" . 
                       ' </access_dirs>' . "\n" . 
                       '  -->' . "\n\n";
            $configtext =~ s/(\r?\n *<api_secret_passphrase>.+?(?=\<\/api_secret_passphrase>)<\/api_secret_passphrase> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if (! exists( $config->{config}->{sms_send_config} ) ) {
        if ( exists( $config->{config}->{ttf} ) ) {
            my $add =  ' <!-- Path to the config file for SMS::Send -->' . "\n" .
                       ' <sms_send_config>/etc/koha/sites/' . $instance . '/sms_send/</sms_send_config>' . "\n";
            $configtext =~ s/(\r?\n *<ttf>.+?(?=\<\/ttf>)<\/ttf> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if (! exists( $config->{config}->{elasticsearch} ) ) {
        if ( exists( $config->{config}->{plack_workers} ) ) {
            my $add =  ' <!-- Configuration for X-Forwarded-For -->' . "\n" . 
                       ' <!--' . "\n" . 
                       ' <koha_trusted_proxies>1.2.3.4 2.3.4.5 3.4.5.6</koha_trusted_proxies>' . "\n" . 
                       ' -->' . "\n" .
                       "\n" . 
                       ' <!-- Elasticsearch Configuration -->' . "\n" .
                       ' <elasticsearch>' . "\n" .
                       '     <server>127.0.0.1:9200</server> <!-- may be repeated to include all servers on your cluster -->' . "\n" .
                       '     <index_name>koha_' . $instance . '</index_name> <!-- should be unique amongst all the indices on your cluster. _biblios and _authorities will be appended. -->' . "\n" .
                       "\n" .
                       '     <!-- See https://metacpan.org/pod/Search::Elasticsearch#cxn_pool -->' . "\n" .
                       '     <cxn_pool>Static</cxn_pool>' . "\n" .
                       '     <!-- See https://metacpan.org/pod/Search::Elasticsearch#trace_to -->' . "\n" .
                       '     <!-- <trace_to>Stderr</trace_to> -->' . "\n" .
                       ' </elasticsearch>' . "\n" .
                       ' <!-- Uncomment the following line if you want to override the Elasticsearch default index settings -->' . "\n" .
                       ' <!-- <elasticsearch_index_config>/etc/koha/sites/' . $instance . '/searchengine/elasticsearch/index_config.yaml</elasticsearch_index_config> -->' . "\n" .
                       ' <!-- Uncomment the following line if you want to override the Elasticsearch default field settings -->' . "\n" .
                       ' <!-- <elasticsearch_field_config>/etc/koha/sites/' . $instance . '/searchengine/elasticsearch/field_config.yaml</elasticsearch_field_config> -->' . "\n" .
                       ' <!-- Uncomment the following line if you want to override the Elasticsearch index default settings.' . "\n" .
                       '      Note that any changes made to the mappings file only take effect if you reset the mappings in' . "\n" .
                       '      by visiting /cgi-bin/koha/admin/searchengine/elasticsearch/mappings.pl?op=reset&i_know_what_i_am_doing=1&reset_fields=1.' . "\n" .
                       '      Resetting mappings will override any changes made in the Search engine configuration UI.' . "\n" .
                       ' -->' . "\n" .
                       ' <!-- <elasticsearch_index_mappings>/etc/koha/sites/' . $instance . '/searchengine/elasticsearch/mappings.yaml</elasticsearch_index_mappings> -->' . "\n" .
                       "\n\n";
            $configtext =~ s/(\r?\n *<plack_workers>.+?(?=\<\/plack_workers>)<\/plack_workers> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    elsif ( $configtext !~ /<!-- Elasticsearch Configuration -->/ ) {
        my $add =  "\n" .
                   ' <!-- Configuration for X-Forwarded-For -->' . "\n" . 
                   ' <!--' . "\n" . 
                   ' <koha_trusted_proxies>1.2.3.4 2.3.4.5 3.4.5.6</koha_trusted_proxies>' . "\n" . 
                   ' -->' . "\n" .
                   "\n" . 
                   ' <!-- Elasticsearch Configuration -->';
        $configtext =~ s/(\r?\n *<elasticsearch>.+?(?=\<\/elasticsearch>)<\/elasticsearch> *\r?\n)/$add$1/is;
        if ( exists( $config->{config}->{elasticsearch}->{server} ) ) {
            $configtext =~ s/<server>localhost:9200<\/server>/'<server>127.0.0.1:9200<\/server> <!-- may be repeated to include all servers on your cluster -->'/se;
        }
        $add = "\n\n" .
               '     <!-- See https://metacpan.org/pod/Search::Elasticsearch#cxn_pool -->';
        $configtext =~ s/(\r?\n *<cxn_pool>.+?(?=\<\/cxn_pool>)<\/cxn_pool> *\r?\n)/$add$1/is;
        $add = "\n" .
               '     <!-- See https://metacpan.org/pod/Search::Elasticsearch#trace_to -->';
        $configtext =~ s/(\r?\n *<trace_to>.+?(?=\<\/trace_to>)<\/trace_to> *\r?\n)/$add$1/is;
        $configtext =~ s/(\r?\n *<!-- <trace_to>.+?(?=\<\/trace_to>)<\/trace_to> --> *\r?\n)/$add$1/is;
        $configtext =~ s/(\r?\n *<!-- <log_to>Stderr<\/log_to> --> *\r?\n)/\n/is;
        $add = ' <!-- Uncomment the following line if you want to override the Elasticsearch default index settings -->' . "\n" .
               ' <!-- <elasticsearch_index_config>/etc/koha/sites/' . $instance . '/searchengine/elasticsearch/index_config.yaml</elasticsearch_index_config> -->' . "\n" .
               ' <!-- Uncomment the following line if you want to override the Elasticsearch default field settings -->' . "\n" .
               ' <!-- <elasticsearch_field_config>/etc/koha/sites/' . $instance . '/searchengine/elasticsearch/field_config.yaml</elasticsearch_field_config> -->' . "\n" .
               ' <!-- Uncomment the following line if you want to override the Elasticsearch index default settings.' . "\n" .
               '      Note that any changes made to the mappings file only take effect if you reset the mappings in' . "\n" .
               '      by visiting /cgi-bin/koha/admin/searchengine/elasticsearch/mappings.pl?op=reset&i_know_what_i_am_doing=1&reset_fields=1.' . "\n" .
               '      Resetting mappings will override any changes made in the Search engine configuration UI.' . "\n" .
               ' -->' . "\n" .
               ' <!-- <elasticsearch_index_mappings>/etc/koha/sites/' . $instance . '/searchengine/elasticsearch/mappings.yaml</elasticsearch_index_mappings> -->' . "\n" .
               "\n";
        $configtext =~ s/(\r?\n *<elasticsearch>.+?(?=\<\/elasticsearch>)<\/elasticsearch> *\r?\n)/$1$add/is;
        $changed = 1;
    }
    if ( exists( $config->{config}->{timezone} ) && $config->{config}->{timezone} eq '' ) {
        $configtext =~ s/<timezone><\/timezone>/'<timezone>Europe\/Berlin<\/timezone>'/se;
    }
    if (! exists( $config->{config}->{bcrypt_settings} ) ) {
        if ( exists( $config->{config}->{timezone} ) ) {
            my $brypt_settings=`htpasswd -bnBC 10 "" password | tr -d ':\n' | sed 's/\$2y/\$2a/'`;
            my $add =  "\n" .
                       ' <!-- This is the bcrypt settings used to generate anonymized content -->' . "\n" .
                       ' <bcrypt_settings>' . xmlEncode($brypt_settings) . '</bcrypt_settings>' . "\n" .
                       '       ' . "\n" .                
                       ' <!-- flag for development purposes' . "\n" .
                       '      dev_install is used to adjust some paths specific to dev installations' . "\n" .
                       '      strict_sql_modes should not be used in a production environment' . "\n" .
                       '      developers use it to catch bugs related to strict SQL modes -->' . "\n" .
                       ' <dev_install>0</dev_install>' . "\n" .
                       ' <strict_sql_modes>0</strict_sql_modes>' . "\n" .
                       ' <plugin_repos>' . "\n" .
                       '    <!--' . "\n" .
                       '    <repo>' . "\n" .
                       '        <name>ByWater Solutions</name>' . "\n" .
                       '        <org_name>bywatersolutions</org_name>' . "\n" .
                       '        <service>github</service>' . "\n" .
                       '    </repo>' . "\n" .
                       '    <repo>' . "\n" .
                       '        <name>Theke Solutions</name>' . "\n" .
                       '        <org_name>thekesolutions</org_name>' . "\n" .
                       '        <service>gitlab</service>' . "\n" .
                       '    </repo>' . "\n" .
                       '    <repo>' . "\n" .
                       '        <name>PTFS Europe</name>' . "\n" .
                       '        <org_name>ptfs-europe</org_name>' . "\n" .
                       '        <service>github</service>' . "\n" .
                       '    </repo>' . "\n" .
                       '    -->' . "\n" .
                       ' </plugin_repos>' . "\n" .
                       "\n" .
                       ' <koha_xslt_security>' . "\n" .
                       ' <!-- Uncomment the following entry ONLY when you explicitly want the XSLT' . "\n" .
                       '      parser to expand entities like <!ENTITY secret SYSTEM "/etc/secrets">.' . "\n" .
                       '      This is unsafe and therefore NOT recommended!' . "\n" .
                       '     <expand_entities_unsafe>1</expand_entities_unsafe>' . "\n" .
                       ' -->' . "\n" .
                       ' </koha_xslt_security>' . "\n" .
                       "\n" .
                       ' <smtp_server>' . "\n" .
                       '    <host>localhost</host>' . "\n" .
                       '    <port>25</port>' . "\n" .
                       '    <timeout>120</timeout>' . "\n" .
                       '    <ssl_mode>disabled</ssl_mode>' . "\n" .
                       '    <user_name></user_name>' . "\n" .
                       '    <password></password>' . "\n" .
                       '    <debug>0</debug>' . "\n" .
                       ' </smtp_server>' . "\n" .
                       "\n" .
                       ' <message_broker>' . "\n" .
                       '   <hostname>localhost</hostname>' . "\n" .
                       '   <port>61613</port>' . "\n" .
                       '   <username>guest</username>' . "\n" .
                       '   <password>guest</password>' . "\n" .
                       '   <vhost></vhost>' . "\n" .
                       ' </message_broker>' . "\n";
            $configtext =~ s/(\r?\n *<timezone>.*?(?=\<\/timezone>)<\/timezone> *\r?\n)/$1$add/is;
            $changed = 1;
        }
    }
    if ( $changed ) {
        my $backupfile = "$conf_fname.backup-".getLoggingTime();
        copy($conf_fname,"$conf_fname.backup-".getLoggingTime());
        print "Backup Koha instance configuration file  $conf_fname as $backupfile\n";
        open(my $fh,'>:encoding(UTF-8)', $conf_fname) or carp "Error opening $conf_fname: $!";
        print $fh $configtext;
        close $fh;
        print "Updated Koha instance configuration file $conf_fname.\n";
    }
}

sub getLoggingTime {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
    my $timestamp = sprintf ( "%04d-%02d-%02d-%02d-%02d-%02d",
                                   $year+1900,$mon+1,$mday,$hour,$min,$sec);
    return $timestamp;
}

sub xmlEncode {
    my $data = shift;
    $data =~ s/&/&amp;/sg;
    $data =~ s/</&lt;/sg;
    $data =~ s/>/&gt;/sg;
    $data =~ s/"/&quot;/sg;
    $data =~ s/'/&apos;/sg;
    return $data;
}

sub updateHiddenColumnsSettings {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("UPDATE columns_settings SET is_hidden = 1 WHERE module = ? AND page = ? AND tablename = ? AND columnname = ?");
    
    $sth->execute('acqui','basket','orders','actual_cost_tax_excluded');
    $sth->execute('acqui','basket','orders','actual_cost_tax_included');
    $sth->execute('acqui','basket','orders','recommended_retail_price_tax_excluded');
    $sth->execute('acqui','basket','orders','recommended_retail_price_tax_included');
    $sth->execute('acqui','basket','orders','replacement_price');
    $sth->execute('acqui','basket','orders','supplier_report');
    $sth->execute('acqui','basket','orders','total_tax_included');
    
    $sth->execute('acqui','lateorders','late_orders','budget');
    
    $sth->execute('acqui','lateorders','suggestions','lastmodificationdate');
    $sth->execute('acqui','lateorders','suggestions','library_fund');
    $sth->execute('acqui','lateorders','suggestions','managed_on');
    
    $sth->execute('catalogue','detail','acquisitiondetails-table','subscription');
    $sth->execute('catalogue','detail','acquisitiondetails-table','subscription_callnumber'); 
    
    $sth->execute('catalogue','detail','holdings_table','holdings_copynumber');
    $sth->execute('catalogue','detail','holdings_table','holdings_course_reserves');
    $sth->execute('catalogue','detail','holdings_table','holdings_dateaccessioned');
    $sth->execute('catalogue','detail','holdings_table','holdings_lastseen');
    $sth->execute('catalogue','detail','holdings_table','holdings_uri');
    $sth->execute('catalogue','detail','holdings_table','holdings_usedin');
    $sth->execute('catalogue','detail','holdings_table','holdings_usedin_col');
    
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_copynumber');
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_course_reserves');
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_dateaccessioned');
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_lastseen');
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_uri');
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_usedin');
    $sth->execute('catalogue','detail','otherholdings_table','otherholdings_usedin_col');
    
    $sth->execute('cataloguing','additem','itemst','booksellerid');
    $sth->execute('cataloguing','additem','itemst','cn_source');
    $sth->execute('cataloguing','additem','itemst','coded_location_qualifier');
    $sth->execute('cataloguing','additem','itemst','copynumber');
    $sth->execute('cataloguing','additem','itemst','datelastborrowed');
    $sth->execute('cataloguing','additem','itemst','datelastseen');
    $sth->execute('cataloguing','additem','itemst','onloan');
    $sth->execute('cataloguing','additem','itemst','price');
    $sth->execute('cataloguing','additem','itemst','replacementpricedate');
    $sth->execute('cataloguing','additem','itemst','restricted');
    $sth->execute('cataloguing','additem','itemst','stack');
    $sth->execute('cataloguing','additem','itemst','stocknumber');
    $sth->execute('cataloguing','additem','itemst','timestamp'); 
    $sth->execute('cataloguing','additem','itemst','uri');
    $sth->execute('cataloguing','additem','itemst','withdrawn');
    $sth->execute('cataloguing','additem','itemst','damaged');
    
    $sth->execute('cataloguing','z3950_search','resultst','lccn');
    
    $sth->execute('circ','circulation','issues-table','checkin');
    $sth->execute('circ','circulation','issues-table','checkout_on_unformatted');
    $sth->execute('circ','circulation','issues-table','collection');
    $sth->execute('circ','circulation','issues-table','copynumber');
    $sth->execute('circ','circulation','issues-table','due_date_unformatted');
    $sth->execute('circ','circulation','issues-table','record_type');
    $sth->execute('circ','circulation','issues-table','sort_order');
    $sth->execute('circ','circulation','issues-table','todays_or_previous_checkouts');
    
    $sth->execute('circ','circulation','table_borrowers','phone');
    
    $sth->execute('circ','holds_awaiting_pickup','holdso','copy_number');
    $sth->execute('circ','holds_awaiting_pickup','holdso','date_hold_placed');

    $sth->execute('circ','holds_awaiting_pickup','holdst','copy_number');
    $sth->execute('circ','holds_awaiting_pickup','holdst','date_hold_placed');
    
    $sth->execute('circ','overdues','circ-overdues','item_type');
    $sth->execute('circ','overdues','circ-overdues','patron_category');
    $sth->execute('circ','overdues','circ-overdues','patron_library');
    $sth->execute('circ','overdues','circ-overdues','price');
    
    $sth->execute('circ','returns','checkedintable','ccode');
    $sth->execute('circ','returns','checkedintable','dateaccessioned');
    $sth->execute('circ','returns','checkedintable','itype');
    $sth->execute('circ','returns','checkedintable','location');
    
    $sth->execute('circ','view_holdsqueue','holds-table','copynumber');
    
    $sth->execute('members','fines','account-fines','checked_out_from');
    $sth->execute('members','fines','account-fines','date_due');
    $sth->execute('members','fines','account-fines','home_library');
    $sth->execute('members','fines','account-fines','issuedate');
    $sth->execute('members','fines','account-fines','returndate');
    $sth->execute('members','fines','account-fines','timestamp');
    
    $sth->execute('members','holdshistory','holdshistory-table','cancellationdate');
    $sth->execute('members','holdshistory','holdshistory-table','waitingdate');
    
    $sth->execute('members','moremember','issues-table','checkin');
    $sth->execute('members','moremember','issues-table','checkout_on_unformatted');
    $sth->execute('members','moremember','issues-table','collection');
    $sth->execute('members','moremember','issues-table','copynumber');
    $sth->execute('members','moremember','issues-table','due_date_unformatted');
    $sth->execute('members','moremember','issues-table','sort_order');
    $sth->execute('members','moremember','issues-table','todays_or_previous_checkouts');
    
    $sth->execute('members','pay','pay-fines-table','checked_out_from');
    $sth->execute('members','pay','pay-fines-table','date_due');
    $sth->execute('members','pay','pay-fines-table','issuedate');
    $sth->execute('members','pay','pay-fines-table','returndate');
    
    $sth->execute('opac','biblio-detail','holdingst','item_copy');
    $sth->execute('opac','biblio-detail','holdingst','item_coursereserves');
    $sth->execute('opac','biblio-detail','holdingst','item_holds');
    $sth->execute('opac','biblio-detail','holdingst','item_shelving_location');
    $sth->execute('opac','biblio-detail','holdingst','item_url');
    
    $sth->execute('opac','biblio-detail','subscriptionst','serial_publisheddate');
    
    $sth->execute('reports','lostitems','lostitems-table','datelastseen');
    $sth->execute('reports','lostitems','lostitems-table','price');
    
    $sth->execute('reports','saved-sql','table_reports','cache_expiry');
    $sth->execute('reports','saved-sql','table_reports','creation_date');
    $sth->execute('reports','saved-sql','table_reports','json_url');
    $sth->execute('reports','saved-sql','table_reports','last_run');
    $sth->execute('reports','saved-sql','table_reports','public');
    $sth->execute('reports','saved-sql','table_reports','saved_results');
    $sth->execute('reports','saved-sql','table_reports','type');
    
    $sth->execute('illrequests','ill-requests','ill-requests','metadata_article_title');
    $sth->execute('illrequests','ill-requests','ill-requests','metadata_issue');
    $sth->execute('illrequests','ill-requests','ill-requests','metadata_volume');
    $sth->execute('illrequests','ill-requests','ill-requests','metadata_year');
    $sth->execute('illrequests','ill-requests','ill-requests','metadata_pages');
    $sth->execute('illrequests','ill-requests','ill-requests','replied');
    $sth->execute('illrequests','ill-requests','ill-requests','completed_formatted');
    $sth->execute('illrequests','ill-requests','ill-requests','accessurl');
    $sth->execute('illrequests','ill-requests','ill-requests','cost');
    $sth->execute('illrequests','ill-requests','ill-requests','comments');
    $sth->execute('illrequests','ill-requests','ill-requests','notesopac');
    $sth->execute('illrequests','ill-requests','ill-requests','notesstaff');
    $sth->execute('illrequests','ill-requests','ill-requests','metadata_checkedBy');
    
    $sth->finish();
    
    print "Default column settings of hidden UI table columns updated.\n";
}

sub updateSimpleVariables {
    my $dbh = C4::Context->dbh;
    $dbh->do("UPDATE systempreferences SET value='' WHERE variable='OpacAdditionalStylesheet' AND value='/webcustom/css/opac-lmscloud.css'");
    $dbh->do("UPDATE systempreferences SET value='1' WHERE variable IN ('AcquisitionLog','AuthFailureLog','AuthoritiesLog','AuthSuccessLog','BorrowersLog','CataloguingLog','ClaimsLog','CronjobLog','DivibibLog','FinesLog','HoldsLog','IllLog','IssueLog','NewsLog','NoticesLog','RenewalLog','ReportsLog','ReturnLog','SubscriptionLog')");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='Mana' and value='2'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='UsageStats' and value='2'");
    $dbh->do("UPDATE systempreferences SET value='Elasticsearch' WHERE variable='SearchEngine'");
    $dbh->do("UPDATE systempreferences SET value='1' WHERE variable='OpacBrowseSearch'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='QueryAutoTruncate'");
    $dbh->do("UPDATE systempreferences SET value='0' WHERE variable='QueryFuzzy'");
    $dbh->do("UPDATE systempreferences SET value='relevance' WHERE variable='defaultSortField'");
    $dbh->do("UPDATE systempreferences SET value='dsc' WHERE variable='defaultSortOrder'");
    $dbh->do("UPDATE systempreferences SET value='NOT homebranch:eBib' WHERE variable='ElasticsearchAdditionalAvailabilitySearch'");
    $dbh->do("UPDATE systempreferences SET value='title,author,subject,title-series,local-classification,publyear,subject-genre-form' WHERE variable='ElasticsearchDefaultAutoCompleteIndexFields'");
    $dbh->do(q{UPDATE systempreferences SET value='[{ "name": "ElasticsearchSuggester", "enabled": 1}, { "name": "AuthorityFile"}, { "name": "ExplodedTerms"}, { "name": "LibrisSpellcheck"}]' WHERE variable='OPACdidyoumean'});
    $dbh->do(q{INSERT IGNORE INTO authorised_value_categories(category_name) VALUES ('MARC-FIELD-336-SELECT')});
    $dbh->do(q{INSERT IGNORE INTO authorised_value_categories(category_name) VALUES ('MARC-FIELD-337-SELECT')});
    $dbh->do(q{INSERT IGNORE INTO authorised_value_categories(category_name) VALUES ('MARC-FIELD-338-SELECT')});
    $dbh->do(q{DELETE FROM authorised_values WHERE category ='MARC-FIELD-336-SELECT'});
    $dbh->do(q{DELETE FROM authorised_values WHERE category ='MARC-FIELD-337-SELECT'});
    $dbh->do(q{DELETE FROM authorised_values WHERE category ='MARC-FIELD-338-SELECT'});
    $dbh->do(q{INSERT INTO authorised_values(category,authorised_value,lib) VALUES 
              ('MARC-FIELD-336-SELECT','cod','Computerdaten'),
              ('MARC-FIELD-336-SELECT','cop','Computerprogramm'),
              ('MARC-FIELD-336-SELECT','crd','kartografischer Datensatz'),
              ('MARC-FIELD-336-SELECT','crf','kartografische dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','cri','kartografisches Bild'),
              ('MARC-FIELD-336-SELECT','crm','kartografisches bewegtes Bild'),
              ('MARC-FIELD-336-SELECT','crn','kartografische taktile dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','crt','kartografisches taktiles Bild'),
              ('MARC-FIELD-336-SELECT','ntm','Noten'),
              ('MARC-FIELD-336-SELECT','ntv','Bewegungsnotation'),
              ('MARC-FIELD-336-SELECT','prm','aufgeführte Musik'),
              ('MARC-FIELD-336-SELECT','snd','Geräusche'),
              ('MARC-FIELD-336-SELECT','spw','gesprochenes Wort'),
              ('MARC-FIELD-336-SELECT','sti','unbewegtes Bild'),
              ('MARC-FIELD-336-SELECT','tcf','taktile dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','tci','taktiles Bild'),
              ('MARC-FIELD-336-SELECT','tcm','taktile Noten'),
              ('MARC-FIELD-336-SELECT','tcn','taktile Bewegungsnotation'),
              ('MARC-FIELD-336-SELECT','tct','taktiler Text'),
              ('MARC-FIELD-336-SELECT','tdf','dreidimensionale Form'),
              ('MARC-FIELD-336-SELECT','tdi','zweidimensionales bewegtes Bild'),
              ('MARC-FIELD-336-SELECT','tdm','dreidimensionales bewegtes Bild'),
              ('MARC-FIELD-336-SELECT','txt','Text'),
              ('MARC-FIELD-336-SELECT','xxx','Sonstige'),
              ('MARC-FIELD-336-SELECT','zzz','nicht spezifiziert'),
              ('MARC-FIELD-337-SELECT','c','Computermedien'),
              ('MARC-FIELD-337-SELECT','e','stereografisch'),
              ('MARC-FIELD-337-SELECT','g','projizierbar'),
              ('MARC-FIELD-337-SELECT','h','Mikroform'),
              ('MARC-FIELD-337-SELECT','n','ohne Hilfsmittel zu benutzen'),
              ('MARC-FIELD-337-SELECT','p','mikroskopisch'),
              ('MARC-FIELD-337-SELECT','s','audio'),
              ('MARC-FIELD-337-SELECT','v','video'),
              ('MARC-FIELD-337-SELECT','x','Sonstige'),
              ('MARC-FIELD-337-SELECT','z','nicht spezifiziert'),
              ('MARC-FIELD-338-SELECT','ca','Magnetbandcartridge'),
              ('MARC-FIELD-338-SELECT','cb','Computerchip-Cartridge'),
              ('MARC-FIELD-338-SELECT','cd','Computerdisk'),
              ('MARC-FIELD-338-SELECT','ce','Computerdisk-Cartridge'),
              ('MARC-FIELD-338-SELECT','cf','Magnetbandkassette'),
              ('MARC-FIELD-338-SELECT','ch','Magnetbandspule'),
              ('MARC-FIELD-338-SELECT','ck','Speicherkarte'),
              ('MARC-FIELD-338-SELECT','cr','Online-Ressource'),
              ('MARC-FIELD-338-SELECT','cz','Sonstige Computermedien'),
              ('MARC-FIELD-338-SELECT','eh','Stereobild'),
              ('MARC-FIELD-338-SELECT','es','Stereografische Disk'),
              ('MARC-FIELD-338-SELECT','ez','Sonstige stereografische Datenträger'),
              ('MARC-FIELD-338-SELECT','gc','Filmstreifen-Cartridge'),
              ('MARC-FIELD-338-SELECT','gd','Filmstreifen für Einzelbildvorführung'),
              ('MARC-FIELD-338-SELECT','gf','Filmstreifen'),
              ('MARC-FIELD-338-SELECT','gs','Dia'),
              ('MARC-FIELD-338-SELECT','gt','Overheadfolie'),
              ('MARC-FIELD-338-SELECT','ha','Mikrofilmlochkarte'),
              ('MARC-FIELD-338-SELECT','hb','Mikrofilm-Cartridge'),
              ('MARC-FIELD-338-SELECT','hc','Mikrofilmkassette'),
              ('MARC-FIELD-338-SELECT','hd','Mikrofilmspule'),
              ('MARC-FIELD-338-SELECT','he','Mikrofiche'),
              ('MARC-FIELD-338-SELECT','hf','Mikrofichekassette'),
              ('MARC-FIELD-338-SELECT','hg','Lichtundurchlässiger Mikrofiche'),
              ('MARC-FIELD-338-SELECT','hh','Mikrofilmstreifen'),
              ('MARC-FIELD-338-SELECT','hj','Mikrofilmrolle'),
              ('MARC-FIELD-338-SELECT','hz','Sonstige Mikroformen'),
              ('MARC-FIELD-338-SELECT','mc','Filmdose'),
              ('MARC-FIELD-338-SELECT','mf','Filmkassette'),
              ('MARC-FIELD-338-SELECT','mo','Filmrolle'),
              ('MARC-FIELD-338-SELECT','mr','Filmspule'),
              ('MARC-FIELD-338-SELECT','mz','Sonstige projizierbare Bilder'),
              ('MARC-FIELD-338-SELECT','na','Rolle'),
              ('MARC-FIELD-338-SELECT','nb','Blatt'),
              ('MARC-FIELD-338-SELECT','nc','Band'),
              ('MARC-FIELD-338-SELECT','nn','Flipchart'),
              ('MARC-FIELD-338-SELECT','no','Karte'),
              ('MARC-FIELD-338-SELECT','nr','Gegenstand'),
              ('MARC-FIELD-338-SELECT','nz','Sonstige Datenträger, die ohne Hilfsmittel zu benutzen sind'),
              ('MARC-FIELD-338-SELECT','pp','Objektträger'),
              ('MARC-FIELD-338-SELECT','pz','Sonstige Mikroskop-Anwendungen'),
              ('MARC-FIELD-338-SELECT','sd','Audiodisk'),
              ('MARC-FIELD-338-SELECT','se','Phonographenzylinder'),
              ('MARC-FIELD-338-SELECT','sg','Audiocartridge'),
              ('MARC-FIELD-338-SELECT','si','Tonspurspule'),
              ('MARC-FIELD-338-SELECT','sq','Notenrolle'),
              ('MARC-FIELD-338-SELECT','ss','Audiokassette'),
              ('MARC-FIELD-338-SELECT','st','Tonbandspule'),
              ('MARC-FIELD-338-SELECT','sz','Sonstige Tonträger'),
              ('MARC-FIELD-338-SELECT','vc','Videocartridge'),
              ('MARC-FIELD-338-SELECT','vd','Videodisk'),
              ('MARC-FIELD-338-SELECT','vf','Videokassette'),
              ('MARC-FIELD-338-SELECT','vr','Videobandspule'),
              ('MARC-FIELD-338-SELECT','vz','Sonstige Videodatenträger'),
              ('MARC-FIELD-338-SELECT','zu','nicht spezifiziert')});
    $dbh->do(q{UPDATE marc_subfield_structure SET value_builder='marc21_field_rda.pl' WHERE tagfield IN ('336','337','338') AND tagsubfield='a' AND frameworkcode = ''});
    $dbh->do(q{UPDATE marc_subfield_structure SET hidden='0' WHERE tagfield IN ('336','337','338') AND tagsubfield='2' AND frameworkcode = ''});
    $dbh->do(q{UPDATE marc_subfield_structure SET hidden='0' WHERE tagfield IN ('336','337','338') AND tagsubfield='a' AND frameworkcode = ''});
    $dbh->do(q{UPDATE marc_subfield_structure SET hidden='0' WHERE tagfield IN ('336','337','338') AND tagsubfield='b' AND frameworkcode = ''});
}

sub updateSidebarLinks {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'OpacDetailBookShopLinkContent%' or variable = 'OpacDetailBookShopLinkContent'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        $value =~ s/<li>\s*<a role="menuitem"/<a class="dropdown-item"/gs;
        $value =~ s/<\/li>//gs;
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub whitener {
    my $searchstring = shift;
    $searchstring =~ s/(\s)/\\$1/g;
    return $searchstring;
}

sub replaceWhitespaceInPhraseSearchKeepingTTSyntax {
    my $searchstring = shift;
    $searchstring =~ s/([^\[%]+)(?!%\])(?=(\[%|$))/whitener($1)/eg;
    $searchstring =~ s/(?<=\[%)([^%|]*[^\s])(?=\s*[%|])/$1.replace(' ','\\ ')/g;
    return $searchstring;
}

sub replaceModifierList {
    my $index = shift;
    my $modifierlist = shift;
    my $searchstring = shift;
    my $quotionMark = '';
    
    if ( $searchstring =~ s/^\s*"(.*)"$/$1/ ) {
        $quotionMark = '"';
    }
    elsif ( $searchstring =~ s/^\s*&quot;(.*)&quot;$/$1/ ) {
        $quotionMark = '&quot;';
    }
    elsif ( $searchstring =~ s/^\s*'(.*)'$/$1/ ) {
        $quotionMark = "'";
    }
    
    my %modifier;
    
    # print "Index ($index), modifier ($modifierlist), search ($searchstring) $quotionMark\n";
    foreach my $mod( grep { $_ =~ s/(^\s+|\s+$)//; $_ ne '' } split(/(,|%2C)/,$modifierlist) ) {
        $modifier{$mod}=1;
    }
    
    $index = 'ocn' if ( $index eq 'lcn' && $searchstring =~ /^\s*(sfb|kab|ssd|asb)/ );
    
    if ( ((defined $modifier{ltrn} && defined $modifier{rtrn}) || defined $modifier{lrtrn} ) && (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) && defined $modifier{ext} ) {
        $searchstring = replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring = '*' . $searchstring . '*';
        $index .= '.phrase';
    }
    elsif ( defined $modifier{rtrn} && (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) ) {
        $searchstring = replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring .= '*';
        $index .= '.phrase';
    }
    elsif ( defined $modifier{ltrn} && (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) ) {
        $searchstring =~ replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring = '*' . $searchstring;
        $index .= '.phrase';
    }
    elsif ( (defined $modifier{phr} || defined $modifier{'first-in-subfield'}) && defined $modifier{ext} ) {
        $searchstring = "$quotionMark$searchstring$quotionMark";
        $index .= '.phrase';
    }
    elsif ( defined $modifier{'first-in-subfield'} ) {
        $searchstring = replaceWhitespaceInPhraseSearchKeepingTTSyntax($searchstring);
        $searchstring = '*' . $searchstring . '*';
        $index .= '.phrase';
    }
    elsif ( defined $modifier{phr} ) {
        $searchstring = "($searchstring)";
    }
    elsif ( (defined $modifier{'st-numeric'} || defined $modifier{'st-date-normalized'} || defined $modifier{'st-date'}) || defined $modifier{ge} || defined $modifier{gt} || defined $modifier{le} || defined $modifier{le} ) {
        if ( defined $modifier{ge} ) {
            $searchstring = "(>=$searchstring)";
        }
        elsif ( defined $modifier{gt} ) {
            $searchstring = "(>$searchstring)";
        }
        elsif ( defined $modifier{le} ) {
            $searchstring = "(<=$searchstring)";
        }
        elsif ( defined $modifier{lt} ) {
            $searchstring = "(<$searchstring)";
        }
        else {
            $searchstring = "($searchstring)";
        }
    }
    elsif( $quotionMark && $searchstring =~ /\s/ ) {
        $searchstring = "($searchstring)";
    }
    
    return "$index:$searchstring";
}

sub updateQuery {
    my $query = shift;
    
    $query =~ s/(\s+(and|or|not)\s+)/uc($1)/seg;
    $query =~ s/=/:/sg;
    $query =~ s/(^|\W)([a-zA-Z][a-z0-9A-Z-]*)(((\,|%2[Cc])(ext|phr|rtrn|ltrn|st-numeric|gt|ge|lt|le|eq|st-date-normalized|st-date|startswithnt|first-in-subfield))*)([:=]|%3[Aa])\s*(["][^"]+["]|&quot;[^"]+&quot;|['][^']+[']|[^\s]+)/$1.replaceModifierList($2,$3,$8)/eg;
    
    # rtrn : right truncation
    # ltrn : left truncation
    # lrtrn : left and right truncation
    # st-date : type date
    # st-numeric : type number (integer)
    # ext : exact search on whole subfield (does not work with icu)
    # phr : search on phrase anywhere in the subfield
    # startswithnt : subfield starts with

    return $query;
}

sub updateEntryPages {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'OpacEntryPage%'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        my $imageAltAdded = 0;
        ($value,$imageAltAdded) = replaceEntryPageContent($value);
    
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable.", ($imageAltAdded ? " $imageAltAdded image alt attributes added." : ""), "\n";
        }
    }
    
    $sth = $dbh->prepare("SELECT idnew,lang,content FROM opac_news WHERE lang like 'OpacNavRight_%' OR lang like 'OpacMainPageLeftPanel_%' OR lang like 'OpacMainUserBlock_%' OR lang like 'OpacLoginInstructions_%' OR lang like 'opacheader_%'");
    $sth->execute;
    while ( my ($id,$name,$value) = $sth->fetchrow ) {
        my $origvalue = $value;
        my $imageAltAdded = 0;
        ($value,$imageAltAdded) = replaceEntryPageContent($value);
    
        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE opac_news SET content=? WHERE idnew=? AND lang=?", undef, $value, $id, $name);
            print "Updated content of new content $name.", ($imageAltAdded ? " $imageAltAdded image alt attributes added." : ""), "\n";
        }
    }
}

sub updateOverwrittenOPACBrowserTemplates {
    my $instance = shift;
    
    my $directory = "/var/lib/koha/$instance/opac-tmpl-custom/bootstrap_upd/*/modules/opac-browser*.tt";
    my @files = glob $directory;
    
    foreach my $filename(@files) {
        my $content;
        {
            local( $/ ); # undefine the record seperator
            open(my $rh,'<:encoding(UTF-8)', $filename) or carp "Error opening $filename $!";
            $content = <$rh>;
            close $rh;
        }
        if ( $content ) {
            my ($changedcontent,$imageAltAdded) = replaceEntryPageContent($content);
            if ( $changedcontent && $changedcontent ne $content ) {
                # my $difftext = diff \$content, \$changedcontent, { STYLE => "Unified" };
                # print "Updated local template $filename\n";
                # print $difftext;
                
                local( $/ ); # undefine the record seperator
                open(my $wh,'>:encoding(UTF-8)', $filename) or carp "Error writing $filename $!";
                print $wh $changedcontent;
                close $wh;
            }
        }
    }
}

sub updateVariablesInNewsTexts {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT branchcode, lang, content FROM opac_news WHERE title like 'OpacNavRight%' OR title like 'OpacMainPageLeftPanel%' OR title like 'OpacMainUserBlock%'");
    $sth->execute;
    while ( my ($branchcode,$lang,$content) = $sth->fetchrow ) {
        my $origvalue = $content;
        my $imageAltAdded = 0;
        ($content,$imageAltAdded) = replaceEntryPageContent($content);
    
        if ( $origvalue ne $content ) {
            $dbh->do("UPDATE opac_news SET content=? WHERE lang=? and branchcode=?", undef, $content, $lang, $branchcode);
            print "Updated opac_news $lang.", ($imageAltAdded ? " $imageAltAdded image alt attributes added." : ""), "\n";
        }
    }
}

sub replaceEntryPageContent {
    my $value = shift;
    
    $value =~ s/(<div[^>]*class\s*=\s*")(([^"]*)(span([1-9][0-2]?))([^"]*))("[^>]*>)/"$1".updateClass($2,$4,"col-lg-$5 entry-page-col")."$7"/eg;
    $value =~ s/(<div[^>]*class\s*=\s*")(([^"]*)(row-fluid)([^"]*))("[^>]*>)/"$1".updateClass($2,$4,"row entry-page-row")."$6"/eg;

    # replace spans
    $value =~ s/span([1-9][0-2]?)/col-lg-$1/g;

    # replace breadcrumb
    if ( $value !~ /<nav aria-label="breadcrumb">/ ) {
        $value =~ s/\n\s*(<ul\s+class\s*=\s*"\s*breadcrumb\s*">.*<\/ul>)/"\n" . replaceBreadcrumb($1)/es;
    }

    # replace rss feed image
    $value =~ s!<img src="[^"]*feed-icon-16x16.png">!<i class="fa fa-rss" aria-hidden="true"></i>!sg;
    
    $value =~ s!(<a\s+href\s*=\s*\'opac-search\.pl\?q=)([^\']+)(\')!"$1".updateQuery($2)."$3"!seg;
    $value =~ s!(<a\s+href\s*=\s*\"opac-search\.pl\?q=)([^\"]+)(\")!"$1".updateQuery($2)."$3"!seg;

    my $documentTree = getDocumentTree($value);
    my $changes = getElementsByName($documentTree, "img", \&addImageAltAttributeFromLegend);
    $value = getDocumentFromTree($documentTree);
    
    return ($value,$changes);
}

sub replaceBreadcrumb {
    my ($oldbreadcrumb) = @_;
    
    my $newbreadcrumb = '    <nav aria-label="breadcrumb">' . "\n".
                        '        <ul class="breadcrumb">' . "\n";
    while ( $oldbreadcrumb =~ m{(<li>(.*?)</li>)}g ) {
        $newbreadcrumb .= '                <li class="breadcrumb-item">' . "\n";
        $newbreadcrumb .= '                    ' . removeDivider($2) . "\n";
        $newbreadcrumb .= '                </li>' . "\n";
    }
    $newbreadcrumb .= '        </ul>' . "\n";
    $newbreadcrumb .= '    </nav>' . "\n";
    
    # print "$oldbreadcrumb\n$newbreadcrumb\n";
    return $newbreadcrumb;
}

sub removeDivider {
    my ($dividervalue) = @_;
    
    $dividervalue =~ s!\s*<span class="divider">&rsaquo;</span>\s*!!mg;
    
    return $dividervalue;
}

sub updateClass {
    my ($classlist, $oldclass, $newclass) = @_;
    
    my @classes = split(/\s+/,$classlist);
    my @newclasses;
    foreach my $class(@classes) {
        if ( $class eq $oldclass ) {
            $class = $newclass;
        }
        push @newclasses, $class;
    }
    return join(" ",@newclasses);
}

sub removeLineTrimmed {
    my $text = shift;
    my $replacements = shift;
    
    foreach my $repl(@$replacements) {
        $text =~ s/[\n][ \t]*\Q$repl\E[ \t]*//g;
    }
    return $text;
}

sub updateMoreSearchesContent {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'OpacMoreSearchesContent_%'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        $value =~ s/<ul>/<ul class="nav" id="moresearches">/;
        $value =~ s/<li>/<li class="nav-item">/g;

        if ( $value !~ m!<a href="/cgi-bin/koha/opac-browse\.pl">! ) {
            my $replace = q{ [% IF Koha.Preference('SearchEngine') == 'Elasticsearch' && Koha.Preference( 'OpacBrowseSearch' ) == 1 %]<li class="nav-item"><a href="/cgi-bin/koha/opac-browse.pl"><i class="fa fa-search-plus" style="color:#4caf50"></i> Indexsuche</a></li>[% END %]};
            if ( $variable =~ /_en$/ ) {
                $replace = q{ [% IF Koha.Preference('SearchEngine') == 'Elasticsearch' && Koha.Preference( 'OpacBrowseSearch' ) == 1 %]<li class="nav-item"><a href="/cgi-bin/koha/opac-browse.pl"><i class="fa fa-search-plus" style="color:#4caf50"></i> Index search</a></li>[% END %]};
            }
            if ( $value =~ m!<li[^>]*><a href="/cgi-bin/koha/opac-search\.pl">(.|\n)*?</li>! ) {
                $value =~ s!(<li[^>]*><a href="/cgi-bin/koha/opac-search\.pl">(.|\n)*?</li>)!"$1\n$replace"!e;
            }
        }

        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub updateIntranetMainUserBlock {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable like 'IntranetmainUserblock'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        $value =~ s/<b>Wichtige Links für Ihre Arbeit:<\/br>(<\/b>)?\r?\n<p>(.+?(?=\<\/p>))<\/p>/'<strong>Wichtige Links für Ihre Arbeit:<\/strong>'.$2/se;

        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub updateOPACUserJS {
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable = 'OPACUserJS'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        my @replace;
        $replace[0] = '$("#availability_facet").hide();';
        $replace[1] = '$("h5#facet-locations").text("Standorte");';
        $replace[2] = '$(".view a:contains(\'MARC\')").hide();';
        $value = removeLineTrimmed($value,\@replace);
        
        $value =~ s/\.holdingst/'#holdingst'/eg;
        $value =~ s/[\n][ \t]*\$\("\.link-collection-collapse-toggle"\)\.on\([^}]+\}\);[ \t]*//s;

        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
    
    $sth = $dbh->prepare("SELECT value,variable FROM systempreferences WHERE variable = 'OPACUserCSS'");
    $sth->execute;
    while ( my ($value,$variable) = $sth->fetchrow ) {
        my $origvalue = $value;
        
        $value =~ s/\.navbar-inverse \.navbar-inner/'#header-region .navbar'/esg;
        $value =~ s/\.navbar-inverse/'.navbar-expanded'/esg;
        $value =~ s/\.brand/'.navbar-brand'/esg;
        $value =~ s/\.navbar-inner/'#cart-list-nav'/esg;

        if ( $origvalue ne $value ) {
            $dbh->do("UPDATE systempreferences SET value=? WHERE variable=?", undef, $value, $variable);
            print "Updated value of variable $variable\n";
        }
    }
}

sub rebuildElasticSearchIndex {
    # Loading Elasticsearch index configuration
    system "/usr/share/koha/bin/search_tools/rebuild_elasticsearch.pl --reset --biblios --verbose --commit 5000 --processes 4";
}


sub getElementAttributeValues {
    my $value = shift;
    
    my $origvalue = $value;
    my $singlequotes = 0;
    if ( $value =~ s/^"([^"]*)"$/$1/ ) {
        $singlequotes = 0;
    }
    elsif ( $value =~ s/^'([^']*)'$/$1/ ) {
        $singlequotes = 1;
    }
    
    my $ret = { origvalue => $origvalue, value => $value, singlequotes => $singlequotes };
    foreach my $val(split(/\s+/,$value)) {
        $ret->{values}->{$val} = 1 if ($val);
    }
    
    return $ret;
}

sub addElementToDocumentTree {
    my ($elementTree,$isEnd,$tagname,$attrtext,$follows,$fullcontent) = @_;
    
    my $attributes = {};
    my $retElem = $elementTree;
    
    my $attrnum = 0;
    while ( $attrtext =~ s/^\s*([\w\-_]+)\s*=\s*("[^"]*"|'[^']*')\s*// ) {
        $attributes->{$1} = getElementAttributeValues($2); 
        $attributes->{$1}->{attrnumber} = ++$attrnum;
    }
    if ( $follows =~ /^(\s*)\/>/ ) {
        my $newElement = { name => $tagname, type => 'elem', tree => [], parent => $elementTree, attributes => $attributes, attrcount => $attrnum, ended => 1, attradd => $attrtext, endfound => 0, spaceend => $1 };
        push @{$elementTree->{tree}}, $newElement;
        $follows =~ s/^\s*[\/>]+//;
        if ( $follows ) {
            push @{$elementTree->{tree}}, { type => 'text', content => $follows };
        }
    }
    elsif (! $isEnd ) {
        my $newElement = { name => $tagname, type => 'elem', tree => [], parent => $elementTree, attributes => $attributes, attrcount => $attrnum, ended => 0, attradd => $attrtext, endfound => 0, spaceend => '' };
        push @{$elementTree->{tree}}, $newElement;
        $follows =~ s/^[>]//;
        if ( $follows ) {
            push @{$newElement->{tree}}, { type => 'text', content => $follows };
        }
        $retElem = $newElement;
    }
    else {
        my $checkElem = $elementTree;
        my $found = 0;
        while ( $checkElem && $checkElem->{name} ) {
            if ( $checkElem->{name} eq $tagname ) {
                $checkElem->{endfound} = 1;
                $found = 1;
                $retElem = $checkElem;
                if ( $retElem->{parent}) {
                    $retElem = $retElem->{parent};
                }
                last;
            } else {
                $checkElem = $checkElem->{parent};
            }
        }
        if ( $found==0 && $tagname =~ /^head$/i ) {
            push @{$retElem->{tree}}, { type => 'text', content => $fullcontent };
        } else {
            $follows =~ s/^[>]//;
            if ( defined($follows) ) {
                push @{$retElem->{tree}}, { type => 'text', content => $follows };
            }
        }
    }
    return $retElem;
}

sub getDocumentTree {
    my ($text) = @_;
    
    my $elementTree = { parent => undef, type => 'root', tree => [] };
    my $root = $elementTree;
    while ( $text =~ s/(<(\/?)(\w+)((\s*[\w\-_]+\s*=\s*("[^"]*"|'[^']*'))*)([^<]+))// ) {
        push @{$elementTree->{tree}}, { type => 'text', content => $` } if ( $` );
        $text = $';
        $elementTree = addElementToDocumentTree($elementTree,$2,$3,$4,$7,$1);
    }
    push @{$elementTree->{tree}}, { type => 'text', content => $text } if ( $text );
    return $root;
}

sub getElementsByName {
    my ($subtree,$name,$function,$returnFirst) = @_;
    
    my $ret = 0;
    
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(root|elem)$/ ) {
        if ( exists($subtree->{name}) && $subtree->{name} =~ /$name/i ) {
            if ( $returnFirst ) {
                return $subtree;
            }
            elsif ( $function ) {
                $ret += $function->($subtree);
            }
        }
        elsif ( exists($subtree->{tree}) && scalar(@{$subtree->{tree}}) > 0 ) {
            foreach my $subentry (@{$subtree->{tree}}) {
                my $elem = getElementsByName($subentry,$name,$function,$returnFirst);
                if ( $elem && $returnFirst ) {
                    return $elem;
                }
                else {
                    $ret += $elem;
                }
            }
        }
    }
    
    return $ret;
}

sub getElementByName {
    my ($subtree,$name) = @_;
    return getElementsByName($subtree,$name,undef,1);
}

sub addImageAltAttributeFromLegend {
    my ($imageElement) = @_;

    if ( exists($imageElement->{name}) && $imageElement->{name} =~ /img/i ) {
        if (! exists($imageElement->{attributes}->{alt}) ) {
            # print "img has no alt attribute\n";
            
            my $parent = $imageElement->{parent};
            my $legend = '';
            while ( $parent ) {
                if (    exists($parent->{type}) && $parent->{type} =~ /^(elem)$/ 
                     && exists($parent->{name}) && $parent->{name} =~ /^(div)$/i
                     && exists($parent->{attributes}) && exists($parent->{attributes}->{class}->{values}->{'ui-tabs-panel'})
                   ) 
                {
                    my $legend = getElementByName($parent,'legend');
                    if ($legend) {
                        if ( exists($legend->{tree}) && scalar(@{$legend->{tree}}) > 0 ) {
                            my $txt = $legend->{tree}->[0]->{content};
                            $txt =~ s/(^\s+|\s+$)//g if ($txt);
                            $txt =~ s/["']//g if ($txt);
                            if ( $txt ) {
                                $imageElement->{attributes}->{alt}->{values} = $txt;
                                $imageElement->{attributes}->{alt}->{value} = $txt;
                                $imageElement->{attrcount} += 1;
                                $imageElement->{attributes}->{alt}->{attrnumber} = $imageElement->{attrcount};
                                return 1;
                            }
                        }
                    }
                }
                $parent = $parent->{parent};
            }
        }
    }
    return 0;
}

sub getDocumentFromTree {
    my ($subtree,$level,$txtarr) = @_;
    
    my $ret = 0;
    if (! $level ) {
        $level = 1;
        $txtarr = [];
    }
    
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(root|elem)$/ && exists($subtree->{name})) {
        my $txt = '<' . $subtree->{name};
        if ( $subtree->{attrcount} ) {
            foreach my $attr( sort { $subtree->{attributes}->{$a}->{attrnumber} <=> $subtree->{attributes}->{$b}->{attrnumber} } keys %{$subtree->{attributes}} ) {
                my $attrquote = '"';
                $attrquote = "'" if ( $subtree->{attributes}->{$attr}->{value} =~ /"/ || $subtree->{attributes}->{$attr}->{singlequotes} );
                $txt .= " $attr=$attrquote" . $subtree->{attributes}->{$attr}->{value} . "$attrquote";
            }
        }
        if ( $subtree->{attradd} ) {
            $txt .= $subtree->{attradd};
        }
        $txt .= $subtree->{spaceend} . "/" if ( $subtree->{ended} );
        $txt .= ">";
        push @$txtarr, $txt;
    }
    if ( exists($subtree->{tree}) && scalar(@{$subtree->{tree}}) > 0 ) {
        for (my $i=0;$i<scalar(@{$subtree->{tree}});$i++) {
            getDocumentFromTree($subtree->{tree}->[$i],$level+1,$txtarr);
        }
    }
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(root|elem)$/ && exists($subtree->{name}) && $subtree->{endfound} && !$subtree->{ended} ) {
        push @$txtarr, '</' . $subtree->{name} . '>';
    }
    if ( exists($subtree->{type}) && $subtree->{type} =~ /^(text)$/ ) {
        push @$txtarr, $subtree->{content};
    }
    
    if ( $level == 1 ) {
        return join('',@$txtarr);
    }
}




# Called individually for each Koha instance of the current host:
# - Check if epayment methods of LMSCloud origin are activated.
#   If this is the case then
#   - fetch the Koha plugin E-Payments-DE from orgaknecht.lmscloud.net
#   - install the Koha plugin E-Payments-DE for the current Koha instance
#   - migrate configuration values of all LMSCloud epayment methods from old systempreferences to new entries in koha_plugin_com_lmscloud_epaymentsde_preferences and to plugin_data.enable_opac_payments
#   - delete the old epayment systempreferences, with exception of 'PaymentsMinimumPatronAge'
#   - do not delete the systempreference 'ActivateCashRegisterTransactionsOnly', because it is not only relevant for epayment.
#   - do not delete the systempreferences 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber' if the standard Koha PayPal e-payment is activated.
#
# - Check if epayment methods of the standard Koha Paypal e-payment is activated.
#   If this is the case then
#   - fetch the adapted Koha plugin pay_via_paypal_lmsc from orgaknecht.lmscloud.net
#   - install the Koha plugin pay_via_paypal_lmsc for the current Koha instance
#   - migrate configuration values of the standard Koha PayPal e-payment method from old systempreferences to new entries in koha_plugin_com_theke_payviapaypal_pay_via_paypal and to plugin_data.enable_opac_payments, plugin_data.PayPalSandboxMode, plugin_data.useBaseURL,
#   - one could delete the old standard Koha PayPal e-payment systempreferences, with exception of 'PaymentsMinimumPatronAge', 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber'
#     (but because this will be done by the standard Koha updateDatabase.pl we skip it here)
#   - do not delete the systempreference 'ActivateCashRegisterTransactionsOnly', because it is not only relevant for epayment.

sub migrate_epayment_to_2105 {
    my ( $migType ) = @_;    # 'LMSC': migrate the LMSC e-payment solutions (GiroSolution, Epay21, PmPayment, EPayBL)   'KohaPayPal': migrate the standard Koha e-payment solution for PayPal

    sub trace {
        my ( $logline ) = @_;
        my $debug = $ENV{'DEBUG_MIGRATE_EPAYMENT'};

        print $logline if $debug;
    }

    sub read_systempreferences {
        my ( $dbh, $selVariable ) = @_;
        my $retValue = '';
	    &trace("migrate_epayment_to_2105::read_systempreferences() START selVariable:$selVariable:\n");

        my $sqlStatement = q{
            SELECT value
            FROM systempreferences
            WHERE  variable = ?;
        };
        &trace("migrate_epayment_to_2105::read_systempreferences() sqlStatement:$sqlStatement:\n");
        my $sth = $dbh->prepare($sqlStatement);
        $sth->execute($selVariable);

        if ( my ($value ) = $sth->fetchrow ) {
            $retValue = $value;
        }

        &trace("migrate_epayment_to_2105::read_systempreferences() END; selVariable:$selVariable: retValue:$retValue:\n");

        return $retValue;
    }


    sub delete_systempreferences {
        my ( $dbh, $selVariable ) = @_;
        my $retValue = '';
	    &trace("migrate_epayment_to_2105::delete_systempreferences() START selVariable:$selVariable:\n");

        my $sqlStatement = q{
            DELETE
            FROM systempreferences
            WHERE  variable = ?;
        };
        &trace("migrate_epayment_to_2105::delete_systempreferences() sqlStatement:$sqlStatement:\n");
        my $sth = $dbh->prepare($sqlStatement);
        $retValue = $sth->execute($selVariable);

        &trace("migrate_epayment_to_2105::delete_systempreferences() END; selVariable:$selVariable: retValue:$retValue:\n");

        return $retValue;
    }


    sub update_epaymentsde_preferences {
        my ( $dbh, $payment_type, $library_id, $name, $value ) = @_;
	    &trace("migrate_epayment_to_2105::update_epaymentsde_preferences() START payment_type:$payment_type: library_id:$library_id: name:$name: value:$value:\n");

        my $sqlStatement = q{
            UPDATE koha_plugin_com_lmscloud_epaymentsde_preferences
               SET value = ?
             WHERE payment_type = ?
               AND library_id = ?
               AND name = ?;
        };
        &trace("migrate_epayment_to_2105::update_epaymentsde_preferences() sqlStatement:$sqlStatement:\n");
        my $sth = $dbh->prepare($sqlStatement);
        my $res = $sth->execute( $value, $payment_type, $library_id, $name );

        &trace("migrate_epayment_to_2105::update_epaymentsde_preferences() END; res:$res:\n");

        return $res;
    }


    sub update_payviapaypal_pay_via_paypal {
        my ( $dbh, $library_id, $active, $user, $pwd, $signature, $charge_description, $threshold ) = @_;
	    &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() START library_id:" . (defined($library_id)?$library_id:'undef') . ": active:$active: user:$user: pwd:$pwd: signature:$signature: signature:$signature: charge_description:$charge_description: threshold:" . (defined($threshold)?$threshold:'undef') . ":\n");

        my $sqlStatement = '';
        my $sth;
        my $res = 'undefined';
        if ( defined($library_id) ) {
            $sqlStatement = q{
                DELETE FROM koha_plugin_com_theke_payviapaypal_pay_via_paypal WHERE library_id = ?;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute( $library_id );
        } else {
            $sqlStatement = q{
                DELETE FROM koha_plugin_com_theke_payviapaypal_pay_via_paypal WHERE library_id IS NULL;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute(  );
        }
        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() 1. sqlStatement:$sqlStatement: res:$res:\n");

        $sqlStatement = q{
            INSERT IGNORE INTO koha_plugin_com_theke_payviapaypal_pay_via_paypal (library_id, active, user, pwd, signature, charge_description, threshold)  VALUES ( ?, ?, ?, ?, ?, ?, ?);
        };
        $sth = $dbh->prepare($sqlStatement);
        $res = $sth->execute( $library_id, $active, $user, $pwd, $signature, $charge_description, $threshold );
        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() 2. sqlStatement:$sqlStatement: res:$res:\n");

        if ( defined($library_id) ) {
            $sqlStatement = q{
                UPDATE koha_plugin_com_theke_payviapaypal_pay_via_paypal
                   SET active = ?,
                       user = ?,
                       pwd = ?,
                       signature = ?,
                       charge_description = ?,
                       threshold = ?
                 WHERE library_id = ?;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute( $active, $user, $pwd, $signature, $charge_description, $threshold, $library_id );
        } else {
            $sqlStatement = q{
                UPDATE koha_plugin_com_theke_payviapaypal_pay_via_paypal
                   SET active = ?,
                       user = ?,
                       pwd = ?,
                       signature = ?,
                       charge_description = ?,
                       threshold = ?
                 WHERE library_id IS NULL;
            };
            $sth = $dbh->prepare($sqlStatement);
            $res = $sth->execute( $active, $user, $pwd, $signature, $charge_description, $threshold );
        }
        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() 3. sqlStatement:$sqlStatement: res:$res:\n");

        &trace("migrate_epayment_to_2105::update_payviapaypal_pay_via_paypal() END; res:$res:\n");

        return $res;
    }


    sub update_plugin_data {
        my ( $dbh, $plugin_class, $plugin_key, $plugin_value ) = @_;
	    &trace("migrate_epayment_to_2105::update_plugin_data() START plugin_class:$plugin_class: plugin_key:$plugin_key: plugin_value:$plugin_value:\n");

        my $sqlStatement = q{
            INSERT IGNORE INTO plugin_data (plugin_class, plugin_key, plugin_value)  VALUES ( ?, ?, ? );
        };
        my $sth = $dbh->prepare($sqlStatement);
        my $res = $sth->execute( $plugin_class, $plugin_key, $plugin_value );
        &trace("migrate_epayment_to_2105::update_plugin_data() 1. sqlStatement:$sqlStatement: res:$res:\n");

        $sqlStatement = q{
            UPDATE plugin_data
               SET plugin_value = ?
             WHERE plugin_class = ?
               AND plugin_key = ?;
        };
        &trace("migrate_epayment_to_2105::update_plugin_data() 2. sqlStatement:$sqlStatement:\n");
        $sth = $dbh->prepare($sqlStatement);
        $res = $sth->execute( $plugin_value, $plugin_class, $plugin_key );

        &trace("migrate_epayment_to_2105::update_plugin_data() END; res:$res:\n");

        return $res;
    }


    sub install_koha_plugin {
        my ( $uploadfilename ) = @_;    # name of the KPZ file
        my $uploaddirname = 'https://orgaknecht.lmscloud.net/updates/koha-21-05/pluginstore';
        #my $uploadlocation = '';
        my $uploadlocation = $uploaddirname . '/' . $uploadfilename;
        my $plugins_enabled = C4::Context->config("enable_plugins");
        my $plugins_dir = C4::Context->config("pluginsdir");
        $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;
        my ( $tempfile, $tfh );
        my %errors;
        my $res = 'undefinedResult';

        &trace("migrate_epayment_to_2105::install_koha_plugin() START; uploadfilename:$uploadfilename: uploadlocation:$uploadlocation: plugins_enabled:$plugins_enabled:\n");

        if ( ! $plugins_enabled ) {
            # set <enable_plugins>1</enable_plugins> in /etc/koha/sites/<instancename>/koha-conf.xml
            my $kohaConfFileName = $ENV{'KOHA_CONF'};
            `sed -i.bak -e 's|<enable_plugins>.*</enable_plugins>|<enable_plugins>1</enable_plugins>|g' $kohaConfFileName`;
            &trace("migrate_epayment_to_2105::install_koha_plugin() updated '$kohaConfFileName'\n");
        }

        my $dirname = File::Temp::tempdir( CLEANUP => 1 );
        &trace("migrate_epayment_to_2105::install_koha_plugin() dirname:$dirname:\n");

        my $filesuffix;
        $filesuffix = $1 if $uploadfilename =~ m/(\..+)$/i;
        ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );

        &trace("migrate_epayment_to_2105::install_koha_plugin() tempfile:$tempfile:\n");

        $errors{'NOTKPZ'} = 1 if ( $uploadfilename !~ /\.kpz$/i );
        $errors{'NOWRITETEMP'}    = 1 unless ( -w $dirname );
        $errors{'NOWRITEPLUGINS'} = 1 unless ( -w $plugins_dir );

        if ( $uploadlocation ) {
            my $ua = Mojo::UserAgent->new(max_redirects => 5);
            my $tx = $ua->get($uploadlocation);
            $tx->result->content->asset->move_to($tempfile);
        } else {
            $errors{'EMPTYUPLOAD'} = 1;
        }

        if ( ! %errors ) {
            my $ae = Archive::Extract->new( archive => $tempfile, type => 'zip' );
            if ( $ae->extract( to => $plugins_dir ) ) {
                &setUserAndGroup( $plugins_dir );

                &trace("migrate_epayment_to_2105::install_koha_plugin() now calling Koha::Plugins->new()->InstallPlugins()\n");
                $res = Koha::Plugins->new()->InstallPlugins();    # returns total count of plugins currently installed on this hosts
            } else {
                $errors{'UZIPFAIL'} = $uploadfilename;
            }
        }

        if ( %errors ) {
            foreach my $key ( keys %errors ) {
                &trace("migrate_epayment_to_2105::install_koha_plugin() errors{$key}:" . $errors{$key} . ":\n");
            }
        }

        &trace("migrate_epayment_to_2105::install_koha_plugin() returns res:$res:\n");
    }

    # recursively set user and group to <koha-Instanz-Name>-koha
    sub setUserAndGroup {
        my ( $dirName ) = @_;
        my $kohaUserName = substr(C4::Context->config('database'),5) . '-koha';    # e.g. koha_wallenheim -> wallenheim-koha

        &trace("migrate_epayment_to_2105::setUserAndGroup() START; dirName:$dirName: kohaUserName:$kohaUserName:\n");

        #`chown -R $kohaUserName:$kohaUserName $dirName`;
        my ($stdoutRes, $stderrRes) = Capture::Tiny::capture {
            system ( "chown -R $kohaUserName:$kohaUserName $dirName" );
        };

        &trace("migrate_epayment_to_2105::setUserAndGroup() tried to chown -R $kohaUserName:$kohaUserName $dirName; stdoutRes:$stdoutRes: stderrRes:$stderrRes:\n");
        if ( $stderrRes ) {
            print "migrate_epayment_to_2105::setUserAndGroup() tried to chown -R $kohaUserName:$kohaUserName $dirName; stdoutRes:$stdoutRes: stderrRes:$stderrRes:\n";
        }
    }

# end of migrate_epayment_to_2105 subs
#################################################################################

    my $dbh = C4::Context->dbh;
    $|=1; # flushes output
    local $dbh->{RaiseError} = 1;

    if ( $migType eq 'LMSC' ) {
        my $lmscPrefCount = 0;
        my $lmscPrefRead = 0;
        my $lmscPrefUpdated = 0;
        my $lmscPrefToDelete = 0;
        my $lmscPrefDeleted = 0;
        my $res = 'noop';

        # systempreferences for the LMSC e-payments (GiroSolution, Epay21, PmPayment, EPayBL)
        my $prefLmsc = {};
        $prefLmsc->{migrate} = 0;    # assumption: no epayment type activated, nothing to migrate

        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{switchName} = 'Epay21PaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{variable}->{Epay21PaypageOpacPaymentsEnabled}->{newName} = 'Epay21PaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{variable}->{Epay21MandantDesc}->{newName} = 'Epay21PaypageMandantDesc';
        $prefLmsc->{pmt}->{epay21}->{pmv}->{Paypage}->{variable}->{Epay21OrderDesc}->{newName} = 'Epay21PaypageOrderDesc';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21AccountingSystemInfo}->{newName} = 'Epay21AccountingSystemInfo';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21App}->{newName} = 'Epay21App';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21BasicAuthPw}->{newName} = 'Epay21BasicAuthPw';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21BasicAuthUser}->{newName} = 'Epay21BasicAuthUser';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21Mandant}->{newName} = 'Epay21Mandant';
        $prefLmsc->{pmt}->{epay21}->{variable}->{Epay21PaypageWebservicesURL}->{newName} = 'Epay21WebservicesURL';

        $prefLmsc->{pmt}->{epaybl}->{pmv}->{Paypage}->{switchName} = 'EpayblPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epaybl}->{pmv}->{Paypage}->{variable}->{EpayblPaypageOpacPaymentsEnabled}->{newName} = 'EPayBLPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{epaybl}->{pmv}->{Paypage}->{variable}->{EpayblPaypagePaypageURL}->{newName} = 'EPayBLPaypageURL';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblAccountingEntryText}->{newName} = 'EPayBLAccountingEntryText';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblDunningProcedureLabel}->{newName} = 'EPayBLDunningProcedureLabel';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblMandatorNumber}->{newName} = 'EPayBLMandatorNumber';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblOperatorNumber}->{newName} = 'EPayBLOperatorNumber';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblPaypageWebservicesURL}->{newName} = 'EPayBLWebservicesURL';
        $prefLmsc->{pmt}->{epaybl}->{variable}->{EpayblSaltHmacSha256}->{newName} = 'EPayBLSaltHmacSha256';

        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{switchName} = 'GirosolutionCreditcardOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{variable}->{GirosolutionCreditcardOpacPaymentsEnabled}->{newName} = 'GiroSolutionCreditcardOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{variable}->{GirosolutionCreditcardProjectId}->{newName} = 'GiroSolutionCreditcardProjectId';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Creditcard}->{variable}->{GirosolutionCreditcardProjectPwd}->{newName} = 'GiroSolutionCreditcardProjectPwd';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{switchName} = 'GirosolutionGiropayOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{variable}->{GirosolutionGiropayOpacPaymentsEnabled}->{newName} = 'GiroSolutionGiropayOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{variable}->{GirosolutionGiropayProjectId}->{newName} = 'GiroSolutionGiropayProjectId';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Giropay}->{variable}->{GirosolutionGiropayProjectPwd}->{newName} = 'GiroSolutionGiropayProjectPwd';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{switchName} = 'GirosolutionPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageOpacPaymentsEnabled}->{newName} = 'GiroSolutionPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageOrderDesc}->{newName} = 'GiroSolutionPaypageOrderDesc';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageOrganizationName}->{newName} = 'GiroSolutionPaypageOrganizationName';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypagePaytypesTestmode}->{newName} = 'GiroSolutionPaypagePaytypesTestmode';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageProjectId}->{newName} = 'GiroSolutionPaypageProjectId';
        $prefLmsc->{pmt}->{girosolution}->{pmv}->{Paypage}->{variable}->{GirosolutionPaypageProjectPwd}->{newName} = 'GiroSolutionPaypageProjectPwd';
        $prefLmsc->{pmt}->{girosolution}->{variable}->{GirosolutionMerchantId}->{newName} = 'GiroSolutionMerchantId';
        $prefLmsc->{pmt}->{girosolution}->{variable}->{GirosolutionRemittanceInfo}->{newName} = 'GiroSolutionRemittanceInfo';

        $prefLmsc->{pmt}->{pmpayment}->{pmv}->{Paypage}->{switchName} = 'PmpaymentPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{pmpayment}->{pmv}->{Paypage}->{variable}->{PmpaymentPaypageOpacPaymentsEnabled}->{newName} = 'PmPaymentPaypageOpacPaymentsEnabled';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentAccountingRecord}->{newName} = 'PmPaymentAccountingRecord';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentAgs}->{newName} = 'PmPaymentAgs';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentPaypageWebservicesURL}->{newName} = 'PmPaymentWebservicesURL';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentProcedure}->{newName} = 'PmPaymentProcedure';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentRemittanceInfo}->{newName} = 'PmPaymentRemittanceInfo';
        $prefLmsc->{pmt}->{pmpayment}->{variable}->{PmpaymentSaltHmacSha256}->{newName} = 'PmPaymentSaltHmacSha256';


        $prefLmsc->{epaymentbase}->{variable}->{ActivateCashRegisterTransactionsOnly}->{newName} = 'EpaymentBaseActivateCashRegisterTransactionsOnly';
        $prefLmsc->{epaymentbase}->{variable}->{PaymentsOnlineCashRegisterManagerCardnumber}->{newName} = 'EpaymentBaseOnlineCashRegisterManagerCardnumber';
        $prefLmsc->{epaymentbase}->{variable}->{PaymentsOnlineCashRegisterName}->{newName} = 'EpaymentBaseOnlineCashRegisterName';

        $prefLmsc->{paypal}->{switchName} = 'EnablePayPalOpacPayments';


        # check if at least 1 LMSC epayment of 18.05 is enabled
        foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
            foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                my $value = &read_systempreferences($dbh, $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{switchName});
                $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{switchValue} = $value;
                if ( $value ) {
                    $prefLmsc->{migrate} = 1;
                    # last;
                }
            }
        }

        # check if the standard Koha PayPal epayment of 18.05 is enabled.
        # In this case do not delete systempreferences 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber'.
        {
            my $value = &read_systempreferences($dbh, $prefLmsc->{paypal}->{switchName});
            $prefLmsc->{paypal}->{switchValue} = $value;
        }

        # read complete LMSC epayment configuration of 18.05
        foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
            &trace("migrate_epayment_to_2105 loop A1 pmnttype:$pmnttype:\n");
            foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                &trace("migrate_epayment_to_2105 loop A2 pmnttype:$pmnttype: pmntvariant:$pmntvariant:\n");
                foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}} ) {
                    &trace("migrate_epayment_to_2105 loop A3 pmnttype:$pmnttype: pmntvariant:$pmntvariant: variable:$variable:\n");
                    $lmscPrefCount += 1;
                    my $value = &read_systempreferences($dbh, $variable);
                    if ( ! $value && $variable =~ /OpacPaymentsEnabled$/ ) {
                        $value = '0';
                    }
                    $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value} = $value;
                    &trace("migrate_epayment_to_2105 loop A3 prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value}:$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value}:\n");
                    if ( defined($value) ) {
                        $lmscPrefRead += 1;
                    }
                }
            }
            foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{variable}} ) {
                &trace("migrate_epayment_to_2105 loop B2 pmnttype:$pmnttype: variable:$variable:\n");
                $lmscPrefCount += 1;
                my $value = &read_systempreferences($dbh, $variable);
                $prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value} = $value;
                &trace("migrate_epayment_to_2105 loop B2 prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value}:$prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value}:\n");
                if ( defined($value) ) {
                    $lmscPrefRead += 1;
                }
            }
        }
        foreach my $variable (sort keys %{$prefLmsc->{epaymentbase}->{variable}} ) {
            &trace("migrate_epayment_to_2105 loop C1 variable:$variable:\n");
            $lmscPrefCount += 1;
            my $value = &read_systempreferences($dbh, $variable);
            $prefLmsc->{epaymentbase}->{variable}->{$variable}->{value} = $value;
            &trace("migrate_epayment_to_2105 loop C1 prefLmsc->{epaymentbase}->{variable}->{$variable}->{value}:$prefLmsc->{epaymentbase}->{variable}->{$variable}->{value}:\n");
            if ( defined($value) ) {
                $lmscPrefRead += 1;
            }
        }
        #&trace("migrate_epayment_to_2105 prefLmsc:" . Dumper($prefLmsc) . ":\n");



        # only if at least 1 LMSC epayment of 18.05 is enabled, we migrate the (complete) LMSC epayment configuration
        if ( $prefLmsc->{migrate} ) {
            # install the plugin E-Payments-DE
            &install_koha_plugin( 'koha-plugin-e-payments-de-v1.0.0.kpz' );

            # store LMSC epayment configuration in 21.05
            foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
                &trace("migrate_epayment_to_2105 loop G1 pmnttype:$pmnttype:\n");
                foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                    &trace("migrate_epayment_to_2105 loop G2 pmnttype:$pmnttype: pmntvariant:$pmntvariant:\n");
                    foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}} ) {
                        my $name = $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{newName};
                        my $value = $prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable}->{value};
                        &trace("migrate_epayment_to_2105 loop G3 pmnttype:$pmnttype: pmntvariant:$pmntvariant: variable:$variable: name:$name: value:$value:\n");
                        my $res = &update_epaymentsde_preferences( $dbh, $pmnttype, 'default', $name, $value );
                        if ( $res eq '1' ) {
                            $lmscPrefUpdated += 1;
                        }
                    }
                }
                foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{variable}} ) {
                    my $name = $prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{newName};
                    my $value = $prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable}->{value};
                    &trace("migrate_epayment_to_2105 loop G2 pmnttype:$pmnttype: variable:$variable: name:$name: value:$value:\n");
                    my $res = &update_epaymentsde_preferences( $dbh, $pmnttype, 'default', $name, $value );
                    if ( $res eq '1' ) {
                        $lmscPrefUpdated += 1;
                    }
                }
            }
            foreach my $variable (sort keys %{$prefLmsc->{epaymentbase}->{variable}} ) {
                &trace("migrate_epayment_to_2105 loop H1 variable:$variable:\n");
                my $name = $prefLmsc->{epaymentbase}->{variable}->{$variable}->{newName};
                my $value = $prefLmsc->{epaymentbase}->{variable}->{$variable}->{value};
                &trace("migrate_epayment_to_2105 loop H1 prefLmsc->{epaymentbase}->{variable}->{$variable}:$variable: name:$name: value:$value:\n");
                my $res = &update_epaymentsde_preferences( $dbh, 'epaymentbase', 'default', $name, $value );
                if ( $res eq '1' ) {
                    $lmscPrefUpdated += 1;
                }
            }
            $res = update_plugin_data( $dbh, 'Koha::Plugin::Com::LMSCloud::EPaymentsDE', 'enable_opac_payments', '1' );
        }

        # In any case we delete the 18.05 system preferences for e-payment, obsolete in 21.05 (exception: ActivateCashRegisterTransactionsOnly, PaymentsMinimumPatronAge)
        foreach my $pmnttype (sort keys %{$prefLmsc->{pmt}} ) {
            &trace("migrate_epayment_to_2105 loop J1 pmnttype:$pmnttype:\n");
            foreach my $pmntvariant (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}} ) {
                &trace("migrate_epayment_to_2105 loop J2 pmnttype:$pmnttype: pmntvariant:$pmntvariant:\n");
                foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}} ) {
                    &trace("migrate_epayment_to_2105 loop J3 pmnttype:$pmnttype: pmntvariant:$pmntvariant: variable:$variable:\n");
                    $lmscPrefToDelete += 1;
                    my $delRes = &delete_systempreferences($dbh, $variable);
                    &trace("migrate_epayment_to_2105 loop J3 prefLmsc->{pmt}->{$pmnttype}->{pmv}->{$pmntvariant}->{variable}->{$variable} deleted:$delRes:\n");
                    if ( defined($delRes) && $delRes == 1 ) {
                        $lmscPrefDeleted += 1;
                    }
                }
            }
            foreach my $variable (sort keys %{$prefLmsc->{pmt}->{$pmnttype}->{variable}} ) {
                &trace("migrate_epayment_to_2105 loop B2 pmnttype:$pmnttype: variable:$variable:\n");
                $lmscPrefToDelete += 1;
                my $delRes = &delete_systempreferences($dbh, $variable);
                &trace("migrate_epayment_to_2105 loop B2 prefLmsc->{pmt}->{$pmnttype}->{variable}->{$variable} deleted:$delRes:\n");
                if ( defined($delRes) && $delRes == 1 ) {
                        $lmscPrefDeleted += 1;
                    }
            }
        }
        foreach my $variable (sort keys %{$prefLmsc->{epaymentbase}->{variable}} ) {
            &trace("migrate_epayment_to_2105 loop C1 variable:$variable:\n");
            if ( $variable eq 'ActivateCashRegisterTransactionsOnly' ) {
                next;
            }
            if ( $variable eq 'PaymentsMinimumPatronAge' ) {
                next;
            }
            if ( $prefLmsc->{paypal}->{switchValue} ) {
                # PayPal requires also in 21.05 the systempreferences 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber'
                if ( $variable eq 'PaymentsOnlineCashRegisterName' ) {
                    next;
                }
                if ( $variable eq 'PaymentsOnlineCashRegisterManagerCardnumber' ) {
                    next;
                }
            }
            $lmscPrefToDelete += 1;
            my $delRes = &delete_systempreferences($dbh, $variable);
            &trace("migrate_epayment_to_2105 loop C1 prefLmsc->{epaymentbase}->{variable}->{$variable} deleted:$delRes:\n");
            if ( defined($delRes) && $delRes == 1 ) {
                $lmscPrefDeleted += 1;
            }
        }


        &trace("migrate_epayment_to_2105 End lmscPrefCount:$lmscPrefCount: lmscPrefRead:$lmscPrefRead: lmscPrefUpdated:$lmscPrefUpdated: lmscPrefToDelete:$lmscPrefToDelete: lmscPrefDeleted:$lmscPrefDeleted: res:$res:\n");

    }


    if ( $migType eq 'KohaPayPal' ) {
        my $paypalPrefCount = 0;
        my $paypalPrefRead = 0;
        my $paypalPrefUpdated = 0;
        my $paypalPrefToDelete = 0;
        my $paypalPrefDeleted = 0;
        my $res = 'noop';

        # systempreferences for the LMSC e-payments (GiroSolution, Epay21, PmPayment, EPayBL)
        my $prefPaypal = {};
        $prefPaypal->{migrate} = 0;    # assumption: no PayPal activated, nothing to migrate

        $prefPaypal->{paypal}->{switchName} = 'EnablePayPalOpacPayments';
        $prefPaypal->{paypal}->{variable}->{EnablePayPalOpacPayments}->{newName} = 'NoDirectEquivalentButIAmHereForDeletionOfMeIn1805Systempreferences';
        $prefPaypal->{paypal}->{variable}->{PayPalChargeDescription}->{newName} = 'charge_description';
        $prefPaypal->{paypal}->{variable}->{PayPalPwd}->{newName} = 'pwd';
        $prefPaypal->{paypal}->{variable}->{PayPalSandboxMode}->{newName} = 'plugin_data.plugin_key';    # to be stored in plugin_data.plugin_key where plugin_class = 'Koha::Plugin::Com::Theke::PayViaPayPal'
        $prefPaypal->{paypal}->{variable}->{PayPalSignature}->{newName} = 'signature';
        $prefPaypal->{paypal}->{variable}->{PayPalUser}->{newName} = 'user';

        # check if the standard Koha PayPal epayment of 18.05 is enabled.
        {
            my $value = &read_systempreferences($dbh, $prefPaypal->{paypal}->{switchName});
            $prefPaypal->{paypal}->{switchValue} = $value;
            if ( $value ) {
                $prefPaypal->{migrate} = 1;
            }
        }


        # read complete PayPal epayment configuration of 18.05
        foreach my $variable (sort keys %{$prefPaypal->{paypal}->{variable}} ) {
            &trace("migrate_epayment_to_2105 loop PPA1 variable:$variable:\n");
            $paypalPrefCount += 1;
            my $value = &read_systempreferences($dbh, $variable);
            $prefPaypal->{paypal}->{variable}->{$variable}->{value} = $value;
            &trace("migrate_epayment_to_2105 loop PPA1 prefPaypal->{paypal}->{variable}->{$variable}->{value}:$prefPaypal->{paypal}->{variable}->{$variable}->{value}:\n");
            if ( defined($value) ) {
                $paypalPrefRead += 1;
            }
        }
        #&trace("migrate_epayment_to_2105 prefPaypal:" . Dumper($prefPaypal) . ":\n");

        # only if PayPal epayment of 18.05 is enabled, we migrate the PayPal specific epayment configuration for the pay_via_paypal plugin.
        # But we continue to use systempreferences 'ActivateCashRegisterTransactionsOnly', 'PaymentsMinimumPatronAge', 'PaymentsOnlineCashRegisterName' and 'PaymentsOnlineCashRegisterManagerCardnumber' also in the pay_via_paypal plugin.
        if ( $prefPaypal->{migrate} ) {
            # install the plugin Pay-Via-PayPal, supplied by Theke Solutions and sligthly modified by LMSCloud
            &install_koha_plugin( 'koha-plugin-pay-via-paypal-v2.3.7_lmsc.kpz' );

            # store PayPal epayment configuration in 21.05 plugin DB table koha_plugin_com_theke_payviapaypal_pay_via_paypal
            {
                my $library_id = undef;
                my $active = 1;
                my $user = $prefPaypal->{paypal}->{variable}->{PayPalUser}->{value};
                my $pwd = $prefPaypal->{paypal}->{variable}->{PayPalPwd}->{value};
                my $signature = $prefPaypal->{paypal}->{variable}->{PayPalSignature}->{value};
                my $charge_description = $prefPaypal->{paypal}->{variable}->{PayPalChargeDescription}->{value};
                my $threshold = undef;

                my $res = &update_payviapaypal_pay_via_paypal( $dbh, $library_id, $active, $user, $pwd, $signature, $charge_description, $threshold );

                if ( $res eq '1' ) {
                    $paypalPrefUpdated += 1;
                }
            }
            $res = update_plugin_data( $dbh, 'Koha::Plugin::Com::Theke::PayViaPayPal', 'useBaseURL', '1' );
            $res += update_plugin_data( $dbh, 'Koha::Plugin::Com::Theke::PayViaPayPal', 'PayPalSandboxMode', $prefPaypal->{paypal}->{variable}->{PayPalSandboxMode}->{value} );
        }

        # In any case we delete the 18.05 system preferences for PayPal epayment, obsolete in 21.05.
        # No, this will be done by the standard Koha updateDatabase.pl, so we skip it here.
#        foreach my $variable (sort keys %{$prefPaypal->{paypal}->{variable}} ) {
#            &trace("migrate_epayment_to_2105 loop PPB1 variable:$variable:\n");
#            $paypalPrefToDelete += 1;
#            my $delRes = &delete_systempreferences($dbh, $variable);
#            &trace("migrate_epayment_to_2105 loop PPB1 prefPaypal->{paypal}->{variable}->{$variable} deleted:$delRes:\n");
#            if ( defined($delRes) && $delRes == 1 ) {
#                    $paypalPrefDeleted += 1;
#                }
#        }

        &trace("migrate_epayment_to_2105 End paypalPrefCount:$paypalPrefCount: paypalPrefRead:$paypalPrefRead: paypalPrefUpdated:$paypalPrefUpdated: paypalPrefToDelete:$paypalPrefToDelete: paypalPrefDeleted:$paypalPrefDeleted: res:$res:\n");
        print "migrate_epayment_to_2105 End paypalPrefCount:$paypalPrefCount: paypalPrefRead:$paypalPrefRead: paypalPrefUpdated:$paypalPrefUpdated: paypalPrefToDelete:$paypalPrefToDelete: paypalPrefDeleted:$paypalPrefDeleted: res:$res:\n";

    }

}

sub createSIPEnabledFile {
    my $instance = shift;
    my $libfile = "/var/lib/koha/$instance/sip.enabled" ;
    
    if ( -f "/etc/koha/sites/$instance/SIPconfig.xml" && ! -f $libfile )  {
        open(my $fh, "<", $libfile);
        close($fh);
        my ($login,$pass,$uid,$gid) = getpwnam("$instance-koha");
        chown $uid, $gid, $libfile;
        chmod 0644, $libfile;
    }
}

sub updateGermanLetterTemplates {
    my $templates = ();
    
    my $text = 
q{[% USE Price %]
[% PROCESS 'accounts.inc' %]
<table>
[% IF ( LibraryName ) %]
 <tr>
    <th colspan="4" class="centerednames">
        <h3>[% LibraryName | html %]</h3>
    </th>
 </tr>
[% END %]
 <tr>
    <th colspan="4" class="centerednames">
        <h2><u>Gebührenquittung</u></h2>
    </th>
 </tr>
 <tr>
    <th colspan="4" class="centerednames">
        <h2>[% Branches.GetName( credit.patron.branchcode ) | html %]</h2>
    </th>
 </tr>
 <tr>
    <th colspan="4">
       Bezahlt von  [% credit.patron.firstname | html %] [% credit.patron.surname | html %]<br />
        Ausweisnummer: [% credit.patron.cardnumber | html %]<br />
    </th>
 </tr>
  <tr>
    <th>Datum</th>
    <th>Gebührenbeschreibung</th>
    <th>Hinweis</th>
    <th>Betrag</th>
 </tr>

 <tr class="highlight">
    <td>[% credit.date | $KohaDates %]</td>
    <td>
      [% PROCESS account_type_description account=credit %]
      [%- IF credit.description %], [% credit.description | html %][% END %]
    </td>
    <td>[% credit.note | html %]</td>
    <td class="credit">[% credit.amount | $Price %]</td>
 </tr>

<tfoot>
  <tr>
    <td colspan="3">Total der Ausstände am: </td>
    [% IF ( credit.patron.account.balance >= 0 ) %]<td class="credit">[% ELSE %]<td class="debit">[% END %][% credit.patron.account.balance | $Price %]</td>
  </tr>
</tfoot>
</table>
};
    push @$templates, ['circulation','ACCOUNT_CREDIT','','Quittung für Anwendung von Guthaben',1,'Quittung für Anwendung von Guthaben',$text,'print','default'];

    
    $text = 
q{[% USE Price %]
[% PROCESS 'accounts.inc' %]
<table>
  [% IF ( LibraryName ) %]
    <tr>
      <th colspan="5" class="centerednames">
        <h3>[% LibraryName | html %]</h3>
      </th>
    </tr>
  [% END %]

  <tr>
    <th colspan="5" class="centerednames">
      <h2><u>RECHNUNG</u></h2>
    </th>
  </tr>
  <tr>
    <th colspan="5" class="centerednames">
      <h2>[% Branches.GetName( debit.patron.branchcode ) | html %]</h2>
    </th>
  </tr>
  <tr>
    <th colspan="5" >
      Rechnung für: [% debit.patron.firstname | html %] [% debit.patron.surname | html %] <br />
      Ausweisnummer: [% debit.patron.cardnumber | html %]<br />
    </th>
  </tr>
  <tr>
    <th>Datum</th>
    <th>Gebührenbeschreibung</th>
    <th>Hinweis</th>
    <th style="text-align:right;">Betrag</th>
    <th style="text-align:right;">Offener Betrag</th>
  </tr>

  <tr class="highlight">
    <td>[% debit.date | $KohaDates%]</td>
    <td>
      [% PROCESS account_type_description account=debit %]
      [%- IF debit.description %], [% debit.description | html %][% END %]
    </td>
    <td>[% debit.note | html %]</td>
    <td class="debit">[% debit.amount | $Price %]</td>
    <td class="debit">[% debit.amountoutstanding | $Price %]</td>
  </tr>

  [% IF ( tendered ) %]
    <tr>
      <td colspan="3">Betrag eingezahlt: </td>
      <td>[% tendered | $Price %]</td>
    </tr>
    <tr>
      <td colspan="3">Rückgeld: </td>
      <td>[% change | $Price %]</td>
    </tr>
  [% END %]

  <tfoot>
    <tr>
      <td colspan="4">Total der Ausstände am: </td>
      [% IF ( debit.patron.account.balance <= 0 ) %]<td class="credit">[% ELSE %]<td class="debit">[% END %][% debit.patron.account.balance | $Price %]</td>
    </tr>
  </tfoot>
</table>
};
    push @$templates, ['circulation','ACCOUNT_DEBIT','','Quittung für offene / teilbezahlte Gebühren',1,'Quittung für offene / teilbezahlte Gebühren',$text,'print','default'];

    $text = 
q{<!DOCTYPE html>
<html>
<head>
<title>Elektronische Zahlungsquittung</title>
</head>
<body dir="auto" style="word-wrap: break-word; -webkit-nbsp-mode: space; line-break: after-white-space; font-family: Arial, sans-serif;">

<h2><<branches.branchname>></h2>
<<branches.opac_info>>
<p>Telefon: <<branches.branchphone>><br />
E-Mail: <<branches.branchreplyto>></p>
<br />
<<borrowers.surname>>, <<borrowers.firstname>><br />
Ausweis-Nummer: <<borrowers.cardnumber>><br />
Ausweis gültig bis: <<borrowers.dateexpiry>>
<br /><br />
<<today>>
<br /><br />

<div style="margin: 0cm 0cm 0.0001pt; font-size: 11pt; font-family: Arial, sans-serif;">
<br />
<br />
<span>
Guten Tag <<borrowers.title>> <<borrowers.firstname>> <<borrowers.surname>>,
</span>
<br />
<br />

[%- USE Price -%]
[%- USE AuthorisedValues -%]

eine Zahlung in Höhe von [% credit.amount * -1 | $Price %] € wurde auf Ihrem Gebührenkonto vorgenommen.<br /><br />

Diese Zahlung betraf die folgenden Gebühren:<br />

[%- FOREACH o IN offsets %]

Beschreibung: [% o.debit.description %]<br />

Eingezahlter Betrag: $[% o.amount * -1 | $Price %]<br />

[% IF ( o.credit.note == 'PayPal' ) %] Bezahlt per: [% o.credit.note %] [% ELSE%] Zahlungsart: [% AuthorisedValues.GetByCode('PAYMENT_TYPE', o.credit.payment_type) %] [% END %]<br /><br />

Offener Restbetrag: $[% o.debit.amountoutstanding | $Price %]<br /><br/ />

[% END %]

Mit freundlichen Grüßen<br />
<br /><br />
- Ihre <<branches.branchname>> -

</div>

</body>
</html>
};
    push @$templates, ['circulation','ACCOUNT_PAYMENT','','Quittung für Gebührenzahlung',1,'Quittung für Gebührenzahlung',$text,'email','default'];

    $text = 
q{<!DOCTYPE html>
<html>
<head>
<title>Elektronische Zahlungsquittung</title>
</head>
<body dir="auto" style="word-wrap: break-word; -webkit-nbsp-mode: space; line-break: after-white-space; font-family: Arial, sans-serif;">

<h2><<branches.branchname>></h2>
<<branches.opac_info>>
<p>Telefon: <<branches.branchphone>><br />
E-Mail: <<branches.branchreplyto>></p>
<br />
<<borrowers.surname>>, <<borrowers.firstname>><br />
Ausweis-Nummer: <<borrowers.cardnumber>><br />
Ausweis gültig bis: <<borrowers.dateexpiry>>
<br /><br />
<<today>>
<br /><br />

<div style="margin: 0cm 0cm 0.0001pt; font-size: 11pt; font-family: Arial, sans-serif;">
<br />
<br />
<span>
Guten Tag <<borrowers.title>> <<borrowers.firstname>> <<borrowers.surname>>,
</span>
<br />
<br />

[%- USE Price -%]
Ein Gebührenerlass in Höhe von [% credit.amount * -1 | $Price %] € wurde auf Ihrem Gebührenkonto vorgenommen.<br /><br />

Dieser Gebührenerlass betrifft die folgenden Gebühren:<br />
[%- FOREACH o IN offsets %]
Beschreibung: [% o.debit.description %]<br />
Betrag eingezahlt: [% o.amount * -1 | $Price %]<br />
Offener Restbetrag: [% o.debit.amountoutstanding | $Price %]<br />
[% END %]

<br /><br />

Mit freundlichen Grüßen<br />
<br /><br />
- Ihre <<branches.branchname>> -


</div>

</body>
</html>
};
    push @$templates, ['circulation','ACCOUNT_WRITEOFF','','Quittung für Gebührenerlass',1,'Quittung für Gebührenerlass',$text,'email','default'];
    
    $text = 
q{Guten Tag [% borrower.firstname %] [% borrower.surname %],

[% IF checkout.auto_renew_error %]
Der Titel [% biblio.title %] konnte nicht korrekt verlängert werden.
[% IF checkout.auto_renew_error == 'too_many' %]
Sie haben die maximale Anzahl an Verlängerungen erreicht.
[% ELSIF checkout.auto_renew_error == 'on_reserve' %]
Dieses Exemplar wurde von anderen Leser*innen vorgemerkt, weswegen keine Verlängerung stattfand.
[% ELSIF checkout.auto_renew_error == 'restriction' %]
es fand keine Verlängerung statt, da Ihr Konto gesperrt wurde.
[% ELSIF checkout.auto_renew_error == 'overdue' %]
Sie haben überfällige Medien ausgeliehen, weswegen keine Verlängerung stattfand.
[% ELSIF checkout.auto_renew_error == 'auto_too_late' %]
Die Frist für die Verlängerung dieses Mediums ist überschritten worden, weswegen keine Verlängerung stattfand.
[% ELSIF checkout.auto_renew_error == 'auto_too_much_oweing' %]
Sie haben den maximal zulässigen Gesamtbetrag ausstehender Gebühren überschritten, weswegen keine Verlängerung stattfand.
[% END %]
[% ELSE %]
Der Titel [% biblio.title %] wurde korrekt verlängert und ist nun am [% checkout.date_due | $KohaDates as_due_date => 1 %] fällig.

[% END %]
};
    push @$templates, ['circulation','AUTO_RENEWALS','','Automatische Verlängerung der Ausleihfrist',0,'Automatische Verlängerung der Ausleihfrist',$text,'email','default'];
    
    $text = 
q{Guten Tag [% borrower.firstname %] [% borrower.surname %],
        [% IF error %]
             [% error %] Medien wurden nicht verlängert.
        [% END %]
        [% IF success %]
             [% success %] Medien wurden verlängert.
        [% END %]
        [% FOREACH checkout IN checkouts %]
            [% checkout.item.biblio.title %] : [% checkout.item.barcode %]
            [% IF !checkout.auto_renew_error %]
                wurde bis zum [% checkout.date_due | $KohaDates as_due_date => 1%] verlängert.
            [% ELSIF checkout.auto_renew_error == 'too_many' %]
                Sie haben die maximale Anzahl an Verlängerungen erreicht.
            [% ELSIF checkout.auto_renew_error == 'on_reserve' %]
                Dieses Exemplar wurde von anderen Leser*innen vorgemerkt, weswegen keine Verlängerung stattfand.
            [% ELSIF checkout.auto_renew_error == 'restriction' %]
                es fand keine Verlängerung statt, da Ihr Konto gesperrt wurde.
            [% ELSIF checkout.auto_renew_error == 'overdue' %]
                Sie haben überfällige Medien ausgeliehen, weswegen keine Verlängerung stattfand.
            [% ELSIF checkout.auto_renew_error == 'auto_too_late' %]
                Die Frist für die Verlängerung dieses Mediums ist überschritten worden, weswegen keine Verlängerung stattfand.
            [% ELSIF checkout.auto_renew_error == 'auto_too_much_oweing' %]
                Sie haben den maximal zulässigen Gesamtbetrag ausstehender Gebühren überschritten, weswegen keine Verlängerung stattfand.
            [% ELSIF checkout.auto_renew_error == 'too_unseen' %]
                Dieses Medium kann nur vor Ort in der Bibliothek verlängert werden.
            [% END %]
        [% END %]
};
    push @$templates, ['circulation','AUTO_RENEWALS_DGST','','Automatische Verlängerung der Ausleihfrist',0,'Automatische Verlängerung der Ausleihfrist',$text,'email','default'];
    
    $text = 
q{<h3>[% branch.branchname %]</h3>
Rückgabequittung für<br />
[% borrower.title %] [% borrower.firstname %] [% borrower.initials %] [% borrower.surname %] <br />
([% borrower.cardnumber %]) <br />

[% today | $KohaDates %]<br />

<h4>Heute zurückgegeben</h4>
[% FOREACH checkin IN old_checkouts %]
[% SET item = checkin.item %]
<p>
[% item.biblio.title %] <br />
Barcode: [% item.barcode %] <br />
</p>
[% END %]

<hr />
<<branches.opac_info>>
};
    push @$templates, ['circulation','CHECKINSLIP','','Rückgabequittung',1,'Rückgabequittung',$text,'print','default'];
    
    $text = 
q{<!DOCTYPE html>
<html>
<head>
<title>Erinnerung an abholbereite Medien</title>
</head>
<body dir="auto" style="word-wrap: break-word; -webkit-nbsp-mode: space; line-break: after-white-space; font-family: Arial, sans-serif;">

<h2><<branches.branchname>></h2>
<<branches.opac_info>>
<p>Telefon: <<branches.branchphone>><br />
E-Mail: <<branches.branchreplyto>></p>
<br />
<<borrowers.surname>>, <<borrowers.firstname>><br />
Ausweis-Nummer: <<borrowers.cardnumber>><br />
Ausweis gültig bis: <<borrowers.dateexpiry>>
<br /><br />
<<today>>
<br /><br />

<div style="margin: 0cm 0cm 0.0001pt; font-size: 11pt; font-family: Arial, sans-serif;">

<br />
<br />

<span>Guten Tag [% borrower.firstname %] [% borrower.surname %],</span>

<br />
<br />

in der Bibliothek [% branch.branchname %] sind folgende von Ihnen vorgemerkten Medien für Sie bereitgestellt worden und noch nicht abgeholt worden:

[% FOREACH hold IN holds %]
    [% hold.biblio.title %] : bereitgestellt seit [% hold.waitingdate | $KohaDates %] <br />
[% END %]

<br /><br />

Bitte holen Sie die Medien zeitnah ab.

<br /><br />

Mit freundlichen Grüßen<br />
<br /><br />
- Ihre <<branches.branchname>> -


</div>

</body>
</html>
};
    push @$templates, ['circulation','HOLD_REMINDER','','Erinnerung an abholbereite Medien',1,'Erinnerung an abholbereite Medien',$text,'email','default'];
    
    $text = 
q{Sehr geehrte Damen und Herren,

wir würden gerne eine Fernleihbestellung für den folgenden Titel anfragen:

[% ill_full_metadata %]

Bitte geben Sie uns eine kurze Rückmeldung, ob Sie diesen Titel per Fernleihe liefern können.

Vielen Dank und mit freundlichen Grüßen

[% branch.branchname %]
[% branch.branchaddress1 %]
[% branch.branchaddress2 %]
[% branch.branchaddress3 %]
[% branch.branchcity %]
[% branch.branchstate %]
[% branch.branchzip %]
[% branch.branchphone %]
[% branch.branchillemail %]
[% branch.branchreplyto %]
};
    push @$templates, ['ill','ILL_PARTNER_REQ','','Fernleihbestellung bei Partnerbibliotheken',0,'Fernleihbestellung',$text,'email','default'];
    
    $text = 
q{Guten Tag [% borrower.firstname %] [% borrower.surname %],

Ihre Fernleihbestellung mit der Bestellnummer [% illrequest.illrequest_id %] für folgenden Titel:

- [% ill_bib_title %] - [% ill_bib_author %]

ist geliefert worden und kann ab sofort in der folgenden Zweigstelle abgeholt werden: [% branch.branchname %].

Vielen Dank und mit freundlichen Grüßen

[% branch.branchname %]
[% branch.branchaddress1 %]
[% branch.branchaddress2 %]
[% branch.branchaddress3 %]
[% branch.branchcity %]
[% branch.branchstate %]
[% branch.branchzip %]
[% branch.branchphone %]
[% branch.branchillemail %]
[% branch.branchreplyto %]
};
    push @$templates, ['ill','ILL_PICKUP_READY','','Abholbernachrichtigung einer Fernleihbestellung',0,'Fernleihbestellung zur Abholung bereit',$text,'email','default'];
    
    $text = 
q{Die/der anfragende Benutzer/in wünscht für die Bestellanfrage für Fernleihbestellung Nummer [% illrequest.illrequest_id %] eine Stornierung und hat dazu den folgenden Hinweis mitgegeben:

[% ill_full_metadata %]
};
    push @$templates, ['ill','ILL_REQUEST_CANCEL','','Stornierung einer Fernleihbestellung',0,'Stornierung einer Fernleihbestellung',$text,'email','default'];

    $text = 
q{Die/der anfragende Benutzer/in hat die Bestellanfrage für Fernleihbestellung Nummer [% illrequest.illrequest_id %] geändert:

[% ill_full_metadata %]
};
    push @$templates, ['ill','ILL_REQUEST_MODIFIED','','Änderung einer Fernleihbestellung',0,'Änderung einer Fernleihbestellung',$text,'email','default'];


    $text = 
q{Guten Tag [% borrower.firstname %] [% borrower.surname %],

Ihre gewünschte Fernleihbestellung mit der Bestellnummer [% illrequest.illrequest_id %] für folgenden Titel:

- [% ill_bib_title %] - [% ill_bib_author %]

kann leider derzeit nicht geliefert werden. Die Bestellanfrage wird hiermit geschlossen.

Mit freundlichen Grüßen

[% branch.branchname %]
[% branch.branchaddress1 %]
[% branch.branchaddress2 %]
[% branch.branchaddress3 %]
[% branch.branchcity %]
[% branch.branchstate %]
[% branch.branchzip %]
[% branch.branchphone %]
[% branch.branchillemail %]
[% branch.branchreplyto %]
};
    push @$templates, ['ill','ILL_REQUEST_UNAVAIL','','Fernleihbestellung nicht lieferbar',0,'Fernleihbestellung nicht lieferbar',$text,'email','default'];
    
    $text = 
q{<!DOCTYPE html>
<html>
<head>
<title>Erinnerung an abholbereite Medien</title>
</head>
<body>
<h2>Anschaffungsvorschlag eingereicht</h2>
<p>
    <h4>Vorgeschlagen von</h4>
    <ul style="list-style-type:none;">
        <li><<borrowers.firstname>> <<borrowers.surname>></li>
        <li><<borrowers.cardnumber>></li>
        <li><<borrowers.phone>></li>
        <li><<borrowers.email>></li>
    </ul>
</p>

<p>
    <h4>Vorgeschlagener Titel</h4>
    <ul style="list-style-type:none;">
        <li><strong>Zweigstelle:</strong> <<branches.branchname>></li>
        <li><strong>Titel:</strong> <<suggestions.title>></li>
        <li><strong>Autor:</strong> <<suggestions.author>></li>
        <li><strong>Erscheinungsdatum:</strong> <<suggestions.copyrightdate>></li>
        <li><strong>Standardnummer (ISBN, ISSN, EAN oder sonstige):</strong> <<suggestions.isbn>></li>
        <li><strong>Verlag:</strong> <<suggestions.publishercode>></li>
        <li><strong>Gesamttitel:</strong> <<suggestions.collectiontitle>></li>
        <li><strong>Verlagsort:</strong> <<suggestions.place>></li>
        <li><strong>Stückzahl:</strong> <<suggestions.quantity>></li>
        <li><strong>Medientyp:</strong> <<suggestions.itemtype>></li>
        <li><strong>Grund:</strong> <<suggestions.patronreason>></li>
        <li><strong>Hinweise:</strong> <<suggestions.note>></li>
    </ul>
</p>
</body>
</html>
};
    push @$templates, ['suggestions','NEW_SUGGESTION','','Anschaffungsvorschlag eingereicht',1,'Anschaffungsvorschlag eingereicht',$text,'email','default'];


    $text = 
q{Guten Tag [% borrower.firstname %] [% borrower.surname %],

folgender Anschaffungsvorschlag wurde Ihnen zugewiesen: [% suggestion.title %].

Vielen Dank
[% branch.branchname %]
};
    push @$templates, ['suggestions','NOTIFY_MANAGER','','Anschaffungsvorschlag zugewiesen',0,'Anschaffungsvorschlag zugewiesen',$text,'email','default'];

    $text = 
q{Es liegt ein neuer Problembericht vor.
    
Benutzername: <<problem_reports.username>>

Das Problem auf folgender Seite gemeldet: <<problem_reports.problempage>>

Titel: <<problem_reports.title>>

Nachricht: <<problem_reports.content>>
};
    push @$templates, ['members','PROBLEM_REPORT','','Neuer Problembericht',0,'Neuer Problembericht',$text,'email','default'];

    $text = 
q{[% PROCESS "accounts.inc" %]
<table>
[% IF ( LibraryName ) %]
 <tr>
    <th colspan="2" class="centerednames">
        <h3>[% LibraryName | html %]</h3>
    </th>
 </tr>
[% END %]
 <tr>
    <th colspan="2" class="centerednames">
        <h2>[% Branches.GetName( payment.branchcode ) | html %]</h2>
    </th>
 </tr>
<tr>
    <th colspan="2" class="centerednames">
        <h3>[% payment.date | $KohaDates %]</h3>
</tr>
<tr>
  <td>Transaktions-ID: </td>
  <td>[% payment.accountlines_id %]</td>
</tr>
<tr>
  <td>Operator-ID: </td>
  <td>[% payment.manager_id %]</td>
</tr>
<tr>
  <td>Zahlungsart: </td>
  <td>[% payment.payment_type %]</td>
</tr>
 <tr></tr>
 <tr>
    <th colspan="2" class="centerednames">
        <h2><u>Gebührenquittung</u></h2>
    </th>
 </tr>
 <tr></tr>
 <tr>
    <th>Gebührenbeschreibung</th>
    <th>Höhe</th>
  </tr>

  [% FOREACH offset IN offsets %]
    <tr>
        <td>[% PROCESS account_type_description account=offset.debit %]</td>
        <td>[% offset.amount * -1 | $Price %]</td>
    </tr>
  [% END %]

<tfoot>
  <tr class="highlight">
    <td>Gesamt: </td>
    <td>[% payment.amount * -1| $Price %]</td>
  </tr>
  <tr>
    <td>Eingezahlt: </td>
    <td>[% collected | $Price %]</td>
  </tr>
  <tr>
    <td>Rückgeld: </td>
    <td>[% change | $Price %]</td>
    </tr>
</tfoot>
</table>
};
    push @$templates, ['pos','RECEIPT','','Kassenbon',1,'Kassenbon',$text,'print','default'];

    $text = 
q{Rotationsbestände - Report für [% branch.name %]:

[% IF branch.items.size %][% branch.items.size %] Medien müssen in dieser Zweigstelle bearbeitet werden.
[% ELSE %]Keine Medien zur Bearbeitung in dieser Zweigstelle.
[% END %][% FOREACH item IN branch.items %][% IF item.reason != 'in-demand' %]Titel: [% item.title %]
Autor: [% item.author %]
Signatur: [% item.callnumber %]
Standort: [% item.location %]
Barcode: [% item.barcode %]
Ausgeliehen?: [% item.onloan %]
Status: [% item.reason %]
Aufenthaltsbibliothek: [% item.branch.branchname %] [% item.branch.branchcode %]

[% END %][% END %]
};
    push @$templates, ['circulation','SR_SLIP','','Rotationsbestand-Bericht',0,'Rotationsbestand-Bericht',$text,'email','default'];
    
    my $dbh = C4::Context->dbh;
    my $sth1 = $dbh->prepare("UPDATE letter SET name = ?, is_html = ?, title = ?, content = ? WHERE module = ? AND code = ? AND branchcode = '' AND message_transport_type = ? AND lang = ?");
    my $sth2 = $dbh->prepare("INSERT INTO letter (module,code,branchcode,name,is_html,title,content,message_transport_type,lang) VALUES (?,?,?,?,?,?,?,?,?)");
    
    foreach my $template (@$templates) {
        my($count) = $dbh->selectrow_array("SELECT COUNT(*) FROM letter WHERE module = ? AND code = ? AND branchcode = '' AND message_transport_type = ? AND lang = ?",
                                           undef,
                                           $template->[0], $template->[1], $template->[7],$template->[8]);
        
        if ( $count == 1 ) {
            $sth1->execute($template->[3], $template->[4], $template->[5], $template->[6], $template->[0], $template->[1], $template->[7], $template->[8]);
        }
        elsif ( $count == 0 ) {
            $sth2->execute($template->[0], $template->[1], $template->[2], $template->[3], $template->[4], $template->[5], $template->[6], $template->[7], $template->[8]);
        }
        else {
            print "Muliple templates found for update: (", join(", ",@$template), "\n";
        }
    }
}

sub updateReports {
    my $updates = ();
    
    my $sqltext = 
q{SELECT
 *
FROM
 (SELECT
 @TargetBranch:=<<Bibliothek|branches>> COLLATE utf8mb4_unicode_ci AS "Medientyp",
 TO_DAYS(@StartDate:=<<Zeitraum von (Datum)|date>>) - TO_DAYS(@EndDate:=<<bis (Datum)|date>>) AS "Anzahl Ausleihen" ) AS set_variables
WHERE 0 = 1
UNION ALL
SELECT 
 "Summe: Alle Medientypen" COLLATE utf8mb4_unicode_ci AS "Medientyp", 
 count(*) AS "Anzahl Ausleihen" 
FROM 
 statistics s 
LEFT JOIN itemtypes i ON s.itemtype=i.itemtype 
WHERE 
 s.type IN ('issue','renew') 
 AND date(s.datetime) BETWEEN @StartDate AND @EndDate 
 AND s.branch=@TargetBranch COLLATE utf8mb4_unicode_ci
UNION ALL
SELECT 
 i.description COLLATE utf8mb4_unicode_ci AS "Medientyp", 
 count(*) AS "Anzahl Ausleihen" 
FROM 
 statistics s 
LEFT JOIN itemtypes i ON s.itemtype=i.itemtype 
WHERE 
 s.type IN ('issue','renew') 
 AND date(s.datetime) BETWEEN @StartDate AND @EndDate
 AND s.branch=@TargetBranch COLLATE utf8mb4_unicode_ci
GROUP BY i.itemtype 
};
    push @$updates, ['A0050 Anzahl Ausleihen (inkl. VL) pro Medientyp in ausgewähltem Zeitraum',$sqltext];
    
    $sqltext = 
q{SELECT
*
FROM
(SELECT
@Jahr:=<<Auswertung für Jahr (JJJJ)>> COLLATE utf8mb4_unicode_ci AS "PLZ",
@TargetBranch:=<<Für Zweigstelle|branches>> COLLATE utf8mb4_unicode_ci AS "Ort",
@StartDate:=<< von |date>> COLLATE utf8mb4_unicode_ci AS "Gesamt",
@EndDate:=<<bis |date>> AS "Bis 12",
" " AS "Ab 60" )
AS set_variables
WHERE 0 = 1
UNION ALL
SELECT zipcode AS"PLZ", city AS "Ort", COUNT(borrowernumber) AS "Gesamt", SUM(IF( @Jahr-YEAR(dateofbirth) <= 12 ,1,0)) AS "Bis 12", SUM(IF( @Jahr-YEAR(dateofbirth) >= 60 ,1,0)) AS "Ab 60" FROM borrowers
WHERE dateexpiry >= @StartDate and dateenrolled <= @EndDate

AND branchcode=@TargetBranch COLLATE utf8mb4_unicode_ci
GROUP BY zipcode
};
    push @$updates, ['B0312-zw Aktive Nutzer nach Sitzkommune und Alter auswerten (für BZSH)',$sqltext];
    
$sqltext = 
q{SELECT
*
FROM
(SELECT
@Jahr:=<<Auswertung für Jahr (JJJJ)>> COLLATE utf8mb4_unicode_ci AS "PLZ",
@TargetBranch:=<<Für Zweigstelle|branches>> COLLATE utf8mb4_unicode_ci AS "Ort",
@StartDate:=<< von |date>> COLLATE utf8mb4_unicode_ci AS "Gesamt",
@EndDate:=<<bis |date>> AS "Bis 12",
" " AS "Ab 60" )
AS set_variables
WHERE 0 = 1
UNION ALL
SELECT zipcode AS"PLZ", city AS "Ort", COUNT(borrowernumber) AS "Gesamt", SUM(IF( @Jahr-YEAR(dateofbirth) <= 12 ,1,0)) AS "Bis 12", SUM(IF( @Jahr-YEAR(dateofbirth) >= 60 ,1,0)) AS "Ab 60" FROM borrowers
WHERE dateexpiry >= @StartDate and dateenrolled <= @EndDate

AND branchcode=@TargetBranch COLLATE utf8mb4_unicode_ci
GROUP BY zipcode
};
    push @$updates, ['B0312-zw Aktive Nutzer nach Sitzkommune und Alter auswerten (für BZSH)',$sqltext];
    
    $sqltext = 
q{SELECT
*
FROM
(SELECT
@Jahr:=<<Auswertung für Jahr (JJJJ)>> COLLATE utf8mb4_unicode_ci AS "PLZ",
@TargetBranch:=<<Für Zweigstelle|branches>> COLLATE utf8mb4_unicode_ci AS "Ort",
@StartDate:=<< von |date>> COLLATE utf8mb4_unicode_ci AS "Gesamt",
@EndDate:=<<bis |date>> AS "Bis 12",
" " AS "Ab 60" )
AS set_variables
WHERE 0 = 1
UNION ALL
SELECT zipcode AS"PLZ", city AS "Ort", COUNT(borrowernumber) AS "Gesamt", SUM(IF( @Jahr-YEAR(dateofbirth) <= 12 ,1,0)) AS "Bis 12", SUM(IF( @Jahr-YEAR(dateofbirth) >= 60 ,1,0)) AS "Ab 60" FROM borrowers
WHERE dateexpiry >= @StartDate and dateenrolled <= @EndDate

AND branchcode=@TargetBranch COLLATE utf8mb4_unicode_ci
GROUP BY zipcode
};

    push @$updates, ['B0312-zw Aktive Nutzer nach Sitzkommune und Alter auswerten (für BZSH)',$sqltext];
    
    $sqltext = 
q{SELECT
adt.description AS "Kostenart",
act.description AS "Zahlungsart",
FORMAT(SUM(a.amount-a.amountoutstanding),2) AS 'Betrag in Euro',
IFNULL(ityp.description,IFNULL(i.itype,'')) AS Medientyp
FROM accountlines a
LEFT JOIN (
SELECT itemnumber, itype FROM deleteditems
UNION
SELECT itemnumber, itype FROM items
) AS i USING (itemnumber)
LEFT JOIN itemtypes ityp ON ityp.itemtype = i.itype
LEFT JOIN account_debit_types adt ON adt.code=a.debit_type_code
LEFT JOIN account_credit_types act ON act.code=a.credit_type_code
WHERE branchcode=<<Auswahl Zweigstelle|branches>>
AND a.amountoutstanding <> a.amount
AND (DATE(a.timestamp) BETWEEN <<Zwischen |date>> AND <<und|date>>)
GROUP BY
a.debit_type_code, a.credit_type_code, i.itype, ityp.description
ORDER BY 1,2,3
};
    push @$updates, ['G0150 Beglichene Gebühren in ausgewähltem Zeitraum summiert nach Gebührenart und Medientyp',$sqltext];
        
    $sqltext = 
q{SELECT
    *
FROM
    (
    SELECT
       '' AS Benutzergruppe,
       (@SelDate1:= <<Von Datum |date>> ) AS "1. Mahnung",
       (@SelDate2:= <<Bis Datum |date>> ) AS "2. Mahnung",
       '0.00' AS "3. Mahnung",
       '0.00'  AS "Bereitstellungsbenachrichtigung",
       '0.00' AS "Summe Gebührenmahnung",
       '0.00' AS "Gesamt"
    ) AS set_variables
WHERE 0 = 1
UNION ALL
SELECT 
       c.description AS Benutzergruppe,
       FORMAT(SUM(claim1),2,'de_DE') AS "1. Mahnung",
       FORMAT(SUM(claim2),2,'de_DE') AS "2. Mahnung",
       FORMAT(SUM(claim3),2,'de_DE') AS "3. Mahnung",
       FORMAT(SUM(hold),2,'de_DE')   AS "Bereitstellungsbenachtichtigung",
       FORMAT(SUM(claimfee),2,'de_DE') AS "Summe Gebührenmahnung",
       FORMAT(SUM(notfall),2,'de_DE') AS "Gesamt"
FROM
       (
            SELECT 
                   b.categorycode AS category,
                   'Normale Bezahlungen' AS Zahlungsform,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 1. Mahnung%',ao.amount,0.0)) * -1 AS claim1,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 2. Mahnung%',ao.amount,0.0)) * -1 AS claim2,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 3. Mahnung%',ao.amount,0.0)) * -1 AS claim3,
                   SUM(IF(a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%',ao.amount,0.0)) * -1 AS hold,
                   SUM(IF(a.description LIKE '__.__.____',ao.amount,0.0)) * -1 AS claimfee,
                   SUM(ao.amount) * -1 AS notfall
            FROM   branches br, account_offsets ao, accountlines c, accountlines a, borrowers b
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = a.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND ao.created_on BETWEEN @SelDate1 AND @SelDate2
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND (
                              a.description LIKE 'Benachrichtigungsgebühr für %. Mahnung%' 
                           OR a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%'
                           OR a.description LIKE 'Gebührenmahnung%'
                           OR a.description LIKE '__.__.____'
                       )
                   AND a.debit_type_code = 'NOTIFICATION'
                   AND ao.amount <> 0.00
                   AND a.borrowernumber = b.borrowernumber
            GROUP BY 
                   a.debit_type_code, b.categorycode
            UNION ALL
            SELECT 
                   b.categorycode AS category,
                   'Erneute Zahlung nach Zahlungsstorno' AS Zahlungsform,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 1. Mahnung%',o.amount,0.0)) * -1 AS claim1,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 2. Mahnung%',o.amount,0.0)) * -1 AS claim2,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 3. Mahnung%',o.amount,0.0)) * -1 AS claim3,
                   SUM(IF(a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%',o.amount,0.0))* -1  AS hold,
                   SUM(IF(a.description LIKE '__.__.____',o.amount,0.0)) * -1 AS claimfee,
                   SUM(o.amount) * -1 AS notfall
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines u, accountlines a, borrowers b
            WHERE      c.branchcode = br.branchcode
                   AND ao.debit_id = u.accountlines_id
                   AND ao.credit_id = c.accountlines_id
                   AND ao.type = 'Payment'
                   AND ao.created_on BETWEEN @SelDate1 AND @SelDate2
                   AND ao.debit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND u.debit_type_code IN ('Pay', 'Pay00', 'Pay01', 'Pay02', 'Pay03')
                   AND (
                              a.description LIKE 'Benachrichtigungsgebühr für %. Mahnung%' 
                           OR a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%'
                           OR a.description LIKE 'Gebührenmahnung%'
                           OR a.description LIKE '__.__.____'
                       )
                   AND a.debit_type_code = 'NOTIFICATION'
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND o.amount <> 0.00
                   AND ao.amount = u.amount
                   AND a.borrowernumber = b.borrowernumber
            GROUP BY 
                   a.debit_type_code, b.categorycode
            UNION ALL
            SELECT 
                   b.categorycode AS category,
                   'Zahlungsstorno' AS Zahlungsform,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 1. Mahnung%',o.amount,0.0)) * -1 AS claim1,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 2. Mahnung%',o.amount,0.0)) * -1 AS claim2,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 3. Mahnung%',o.amount,0.0)) * -1 AS claim3,
                   SUM(IF(a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%',o.amount,0.0)) * -1 AS hold,
                   SUM(IF(a.description LIKE '__.__.____',o.amount,0.0)) * -1 AS claimfee,
                   SUM(o.amount) * -1 AS notfall
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a, borrowers b
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.credit_id = c.accountlines_id
                   AND ao.amount > 0.0
                   AND ao.created_on BETWEEN @SelDate1 AND @SelDate2
                   AND ao.credit_id = o.credit_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND (
                              a.description LIKE 'Benachrichtigungsgebühr für %. Mahnung%' 
                           OR a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%'
                           OR a.description LIKE 'Gebührenmahnung%'
                           OR a.description LIKE '__.__.____'
                       )
                   AND a.debit_type_code = 'NOTIFICATION'
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND o.amount <> 0.00
                   AND -ao.amount = c.amount
                   AND a.borrowernumber = b.borrowernumber
            GROUP BY 
                   a.debit_type_code, b.categorycode
            UNION ALL
            SELECT 
                   b.categorycode AS category,
                   'Rückzahlungen' AS Zahlungsform,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 1. Mahnung%',o.amount,0.0)) AS claim1,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 2. Mahnung%',o.amount,0.0)) AS claim2,
                   SUM(IF(a.description LIKE 'Benachrichtigungsgebühr für 3. Mahnung%',o.amount,0.0)) AS claim3,
                   SUM(IF(a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%',o.amount,0.0)) AS hold,
                   SUM(IF(a.description LIKE '__.__.____',o.amount,0.0)) AS claimfee,
                   SUM(o.amount) AS notfall
            FROM   branches br, account_offsets o, account_offsets ao, accountlines c, accountlines a, borrowers b
            WHERE      c.branchcode = br.branchcode
                   AND ao.type = 'Reverse Payment'
                   AND ao.amount < 0.0
                   AND ao.created_on BETWEEN @SelDate1 AND @SelDate2
                   AND ao.credit_id = o.credit_id
                   AND ao.credit_id = c.accountlines_id
                   AND o.type = 'Payment'
                   AND o.debit_id = a.accountlines_id
                   AND (
                              a.description LIKE 'Benachrichtigungsgebühr für %. Mahnung%' 
                           OR a.description LIKE 'Gebühr für Bereitstellungsbenachrichtigung%'
                           OR a.description LIKE 'Gebührenmahnung%'
                           OR a.description LIKE '__.__.____'
                       )
                   AND a.debit_type_code = 'NOTIFICATION'
                   AND NOT EXISTS (SELECT 1 FROM items WHERE a.itemnumber = items.itemnumber)
                   AND NOT EXISTS (SELECT 1 FROM deleteditems WHERE a.itemnumber = deleteditems.itemnumber)
                   AND o.amount <> 0.00
                   AND a.borrowernumber = b.borrowernumber
             GROUP BY 
                   a.debit_type_code, b.categorycode
       ) AS notf, categories c
WHERE  notf.category = c.categorycode
GROUP BY c.description
};
    push @$updates, ['G0010 Benachrichtigungsgebühren nach Art für ausgewählten Zeitraum',$sqltext];

    $sqltext = 
q{SELECT 
 '<b>Summe gesamt</b>' AS 'Einnahme von', 
 '<b>Summe gesamt</b>' AS 'Gebühr erhoben von', 
 '<b>Betrag gesamt</b>' AS Betrag,
 '<b>Transfer</b>' AS Gebührenart, 
 '<b>Transferbetrag</b>' AS Verrechnung
FROM dual
WHERE
 CURDATE() >= ( @FromDate:= <<Von Datum |date>> ) AND CURDATE() >= ( @ToDate:= <<Bis Datum |date>> )
UNION ALL
SELECT 
 br2.branchname AS 'Einnahme von', 
 br1.branchname AS 'Gebühr erhoben von', 
 FORMAT(origsum.betrag, 2, 'de_DE') AS Betrag,
 CASE
 WHEN (origsum.betrag - addsum.betrag) > 0.0 THEN CONCAT('VON ',br2.branchname, ' <br />NACH ',br1.branchname)
 WHEN addsum.betrag IS NULL THEN CONCAT('VON ',br2.branchname, ' <br />NACH ',br1.branchname)
 ELSE ''
 END AS Gebührenart,
 CASE
 WHEN (origsum.betrag - addsum.betrag) > 0.0 THEN FORMAT(origsum.betrag - addsum.betrag, 2, 'de_DE')
 WHEN addsum.betrag IS NULL THEN FORMAT(origsum.betrag, 2, 'de_DE')
 ELSE ''
 END AS Verrechnung
FROM 
 (
  SELECT 
 c.branchcode AS angefallen, 
 p.branchcode AS bezahlt, 
 SUM(op.amount * -1) AS betrag
 FROM accountlines p, 
 account_offsets op, 
 accountlines c
 WHERE 
 p.credit_type_code="PAYMENT"
 AND op.credit_id = p.accountlines_id
 AND p.branchcode <> c.branchcode
 AND op.debit_id = c.accountlines_id
 AND DATE(op.created_on) BETWEEN @FromDate AND @ToDate
 GROUP BY c.branchcode, p.branchcode 
 ORDER BY betrag DESC ) AS origsum
 LEFT JOIN 
 (
 SELECT 
 c.branchcode AS angefallen, 
 p.branchcode AS bezahlt, 
 SUM(op.amount * -1) AS betrag
 FROM accountlines p, 
 account_offsets op, 
 accountlines c
 WHERE 
 p.credit_type_code="PAYMENT"
 AND op.credit_id = p.accountlines_id
 AND p.branchcode <> c.branchcode
 AND op.debit_id = c.accountlines_id
 AND DATE(op.created_on) BETWEEN @FromDate AND @ToDate
 GROUP BY c.branchcode, p.branchcode
 ) AS addsum ON ( origsum.angefallen = addsum.bezahlt AND origsum.bezahlt = addsum.angefallen )
 LEFT JOIN branches br1 ON ( origsum.angefallen = br1.branchcode )
 LEFT JOIN branches br2 ON ( origsum.bezahlt = br2.branchcode )
UNION ALL
SELECT 
 '<hr />' AS 'Einnahme von', 
 '<hr />' AS 'Gebühr erhoben von', 
 '<hr />' AS Betrag,
 '<hr />' AS Gebührenart, 
 '<hr />' AS Verrechnung
UNION ALL
SELECT 
 '<b>Summe nach Gebührenart</b>' AS 'Einnahme von', 
 '<b>Summe nach Gebührenart</b>' AS 'Gebühr erhoben von', 
 '<b>Betrag</b>' AS Betrag,
 '<b>Gebührenart</b>' AS Gebührenart, 
 '' AS Verrechnung
UNION ALL

SELECT 
 br1.branchname AS 'Einnahme von', 
 br2.branchname AS 'Gebühr erhoben von', 
 FORMAT(SUM(op.amount * -1), 2, 'de_DE') AS Betrag, 
 deb.description AS Gebührenart, 
 '' AS Verrechnung
FROM accountlines p
 LEFT JOIN branches br1 ON ( p.branchcode = br1.branchcode ), 
 account_offsets op, 
 accountlines c
 LEFT JOIN account_debit_types deb ON deb.code=c.debit_type_code
 LEFT JOIN borrowers b ON ( b.borrowernumber = c.borrowernumber AND (deb.code = 'ACCOUNT_RENEW' OR deb.code='ACCOUNT'))
 LEFT JOIN categories g ON ( b.categorycode = g.categorycode )
 LEFT JOIN branches br2 ON ( c.branchcode = br2.branchcode )
WHERE 
 p.credit_type_code="PAYMENT"
 AND op.credit_id = p.accountlines_id
 AND p.branchcode <> c.branchcode
 AND op.debit_id = c.accountlines_id
 AND DATE(op.created_on) BETWEEN @FromDate AND @ToDate
GROUP BY c.branchcode, p.branchcode, c.debit_type_code, g.description
};
    push @$updates, ['G0100-zw Einnahmenverrechnung zwischen Zweigstellen',$sqltext];
    
    $sqltext = 
q{SELECT accountlines_id AS 'Vorgangsnr.', DATE_FORMAT(date,'%d.%m.%Y') AS 'Datum', timestamp, FORMAT(amount,2,'de_DE') AS 'Betrag',FORMAT(amountoutstanding,2,'de_DE') AS 'Betrag offen', deb.description AS 'Beschreibung', 
deb.code AS 'Vorgangsart',
b1.cardnumber AS 'Ausweisnummer', CONCAT(b1.firstname, " ",b1.surname) AS 'Benutzername', note AS 'Bemerkung' , b2.surname AS 'Mitarbeitername' 
FROM accountlines
LEFT JOIN borrowers b1 ON (accountlines.borrowernumber=b1.borrowernumber) 
LEFT JOIN borrowers b2 ON (accountlines.manager_id=b2.borrowernumber) 
LEFT JOIN account_debit_types deb ON deb.code=accountlines.debit_type_code
WHERE date >= <<Von|date>> AND date <= <<bis|date>>
ORDER BY date, accountlines_id
};
    push @$updates, ['G0140 Gebührenvorgänge - Einzelauflistung für einen auswählbaren Zeitraum',$sqltext];
    
    $sqltext = 
q{SELECT CONCAT('<a href=\"/cgi-bin/koha/members/boraccount.pl?borrowernumber=',borrowers.borrowernumber,'\" target="_blank">', borrowers.borrowernumber, '</a>') AS borrowernumber,
 borrowers.cardnumber AS Ausweisnummer,
 borrowers.firstname AS Vorname,
 borrowers.surname AS Nachname,
 borrowers.branchcode AS Heimatzweigstelle,
 FORMAT(accountlines.amount,2) AS Betrag,
 accountlines.date AS Datum, 
 accountlines.credit_type_code AS Typ,
 accountlines.note AS Grund,
 accountlines.manager_id
FROM accountlines, borrowers
WHERE borrowers.borrowernumber = accountlines.borrowernumber 
AND credit_type_code IN ('WRITEOFF','CANCELLATION','DISCOUNT','FORGIVEN')
AND date BETWEEN <<Von|date>> AND <<Bis|date>>
ORDER BY accountlines.credit_type_code
};
    push @$updates, ['G0200 Gebührenerlass / Storno mit Grund für einen wählbaren Zeitraum',$sqltext];
    
    $sqltext = 
q{SELECT
*
FROM
(
SELECT
0 AS Zweigstelle,
0 AS Exemplarnummer,
0 AS Buchungsnummer,
0 AS Zugangsdatum,
( @StartDate:= <<Von Datum|date>> COLLATE utf8mb4_unicode_ci ) AS Standort,
0 AS Autor,
0 AS Titel,
0 AS Sammlung,
( @EndDate:= <<Bis Datum|date>> COLLATE utf8mb4_unicode_ci ) AS Medientyp,

0 AS Preis,
0 AS Status
) AS set_variables
WHERE 0 = 1

UNION

SELECT
homebranch AS Zweigstelle ,
itemnumber AS Exemplarnummer,
barcode AS Buchungsnummer,
DATE_FORMAT(dateaccessioned, '%d.%m.%Y') AS Zugangsdatum,
lib AS Standort,
author AS Autor,
title AS Titel,
lib2 AS Sammlung,
itype AS Medientyp,
FORMAT(price, 2, 'de_DE') AS Preis,
status AS Status

FROM (

SELECT homebranch, itemnumber, barcode, dateaccessioned, av.lib, av2.lib as lib2, b.author, b. title, itype, price, IF(onloan IS NOT NULL,'entliehen','verfügbar') AS status FROM items
LEFT JOIN biblio b USING (biblionumber)
LEFT JOIN authorised_values av ON ( av.authorised_value = location AND av.category = 'LOC')
LEFT JOIN authorised_values av2 ON ( av2.authorised_value = ccode AND av2.category = 'CCODE')
WHERE (date(dateaccessioned) BETWEEN @StartDate AND @EndDate) AND (itype is null OR itype NOT LIKE "e%")
UNION
SELECT homebranch, itemnumber, barcode, dateaccessioned, av.lib, av2.lib as lib2, b.author , b. title, itype, price, 'gelöscht' AS status FROM deleteditems
LEFT JOIN deletedbiblio b USING (biblionumber)
LEFT JOIN authorised_values av ON ( av.authorised_value = location AND av.category = 'LOC')
LEFT JOIN authorised_values av2 ON ( av2.authorised_value = ccode AND av2.category = 'CCODE')
WHERE (date(dateaccessioned) BETWEEN @StartDate AND @EndDate) AND (itype is null OR itype NOT LIKE "e%")

) AS allitems

ORDER BY Zugangsdatum
};
    push @$updates, ['K0030 Zugangsbuch',$sqltext];
    
    my $dbh = C4::Context->dbh;
    my $sth1 = $dbh->prepare("UPDATE saved_sql SET savedsql = ? WHERE report_name = BINARY ?");
    
    foreach my $update (@$updates) {
        $sth1->execute($update->[1], $update->[0]);
    }
}
