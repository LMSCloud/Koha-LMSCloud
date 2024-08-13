use Modern::Perl;

return {
    bug_number => "",
    description => "Update use of datepicker to flatpickr in content of preference ILLPFLPortalURLOpac.",
    up => sub {
        my ($args) = @_;
        my ($dbh, $out) = @$args{qw(dbh out)};
        
        my $sth = $dbh->prepare('SELECT value FROM systempreferences WHERE variable = ?');
        
        my $changed = 0;
        $sth->execute('ILLPFLPortalURLOpac');
        if ( my ($value) = $sth->fetchrow_array ) {
            my $searchval = q{<input type="text" class="datepicker" name="attributes_BenoetigtBis" id="attributes_BenoetigtBis" size="10" maxlength="10" value="" />};
            my $replval   = q{<input type="text" class="flatpickr" data-flatpickr-futuredate="true" name="attributes_BenoetigtBis" id="attributes_BenoetigtBis" size="10" maxlength="10" value="" />};
            
            my $changed = 0;
            $changed = 1 if ( $value =~ s/\Q$searchval\E/$replval/gs );
            
            $searchval = q{document.getElementById("attributes_BenoetigtBis").setAttribute("value", "[% whole.value.other.attributes_BenoetigtBis | $KohaDates %]");};
            $replval   = q{document.getElementById("attributes_BenoetigtBis")._flatpickr.setDate( "[% whole.value.other.attributes_BenoetigtBis %]" );};
            
            $changed = 1 if ( $value =~ s/\Q$searchval\E/$replval/gs );
            
            if ( $changed ) {
                $dbh->do('UPDATE systempreferences SET value = ? WHERE variable = ?',undef,$value,'ILLPFLPortalURLOpac');
                say $out "System preference ILLPFLPortalURLOpac updated.";
            }
            else {
                say $out "Update of system preference ILLPFLPortalURLOpac not necessary.";
            }
        }
        else {
            say $out "System preference ILLPFLPortalURLOpac not defined.";
        }
    },
};
