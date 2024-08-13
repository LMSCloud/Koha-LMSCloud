use Modern::Perl;

return {
    bug_number => "",
    description => "UPDATE default letters to German.",
    up => sub {
        my ($args) = @_;
        my ($dbh) = @$args{qw(dbh)};
 
        
        ###############  AR_REQUESTED 
        
        my         $content = 
q{<p>Guten Tag <<borrowers.firstname>> <<borrowers.surname>>,</p>

<p>Ihre Artikelbestellung für <<biblio.title>> [% IF item && item.barcode %]([% item.barcode %])[% END %] ist bei uns eingegangen.</p>

<p>Ihre Artikelbestellung:<br />
Titel: <<article_requests.title>><br />
Autor: <<article_requests.author>><br />
Band: <<article_requests.volume>><br />
Heft: <<article_requests.issue>><br />
Datum: <<article_requests.date>><br />
Inhaltsverzeichnis: [% IF article_request.toc_request %]Ja[% ELSE %]Nein[% END %]
Seitenangaben: <<article_requests.pages>><br />
Kapitel: <<article_requests.chapters>><br />
Hinweise: <<article_requests.patron_notes>><br /><br />

Vielen Dank.<br>
Ihr Bibliotheksteam<br>
<<branches.branchname>></p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Neue Artikelbestellung','circulation', 'AR_REQUESTED');


        ###############  AR_PROCESSING 

        $content = 
q{<p>Guten Tag <<borrowers.firstname>> <<borrowers.surname>>,</p>

<p>Ihre Artikelbestellung für <<biblio.title>> [% IF item && item.barcode %]([% item.barcode %])[% END %] wird bearbeitet.</p>

<p>Ihre Artikelbestellung:<br />
Titel: <<article_requests.title>><br />
Autor: <<article_requests.author>><br />
Band: <<article_requests.volume>><br />
Heft: <<article_requests.issue>><br />
Datum: <<article_requests.date>><br />
Inhaltsverzeichnis: [% IF article_request.toc_request %]Ja[% ELSE %]Nein[% END %]
Seitenangaben: <<article_requests.pages>><br />
Kapitel: <<article_requests.chapters>><br />
Hinweise: <<article_requests.patron_notes>><br /><br />

Vielen Dank.<br>
Ihr Bibliotheksteam<br>
<<branches.branchname>></p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Artikelbestellung in Bearbeitung', 'circulation', 'AR_PROCESSING');


        ###############  AR_CANCELED 

        $content = 
q{<p>Guten Tag <<borrowers.firstname>> <<borrowers.surname>>,</p>

<p>Ihre Artikelbestellung für <<biblio.title>> [% IF item && item.barcode %]([% item.barcode %])[% END %] kann leider nicht erfüllt werden.<br>
<<reason>>
</p>


<p>Ihre Artikelbestellung:<br />
Titel: <<article_requests.title>><br />
Autor: <<article_requests.author>><br />
Band: <<article_requests.volume>><br />
Heft: <<article_requests.issue>><br />
Datum: <<article_requests.date>><br />
Inhaltsverzeichnis: [% IF article_request.toc_request %]Ja[% ELSE %]Nein[% END %]
Seitenangaben: <<article_requests.pages>><br />
Kapitel: <<article_requests.chapters>><br />
Hinweise: <<article_requests.patron_notes>><br /><br />

Vielen Dank.<br>
Ihr Bibliotheksteam<br>
<<branches.branchname>></p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Artikelbestellung storniert', 'circulation', 'AR_CANCELED');

        ###############  AR_COMPLETED 

        $content = 
q{<p>Guten Tag <<borrowers.firstname>> <<borrowers.surname>>,</p>

<p>Ihre Artikelbestellung für <<biblio.title>> [% IF item && item.barcode %]([% item.barcode %])[% END %] wurde fertig bearbeitet.</p>

<p>Ihre Artikelbestellung:<br />
Titel: <<article_requests.title>><br />
Autor: <<article_requests.author>><br />
Band: <<article_requests.volume>><br />
Heft: <<article_requests.issue>><br />
Datum: <<article_requests.date>><br />
Inhaltsverzeichnis: [% IF article_request.toc_request %]Ja[% ELSE %]Nein[% END %]
Seitenangaben: <<article_requests.pages>><br />
Kapitel: <<article_requests.chapters>><br />
Hinweise: <<article_requests.patron_notes>><br /><br />

Bitte holen Sie den Artikel an folgendem Standort ab: <<branches.branchname>>.

Vielen Dank.<br>
Ihr Bibliotheksteam<br>
<<branches.branchname>></p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Artikelbestellung abgeschlossen', 'circulation', 'AR_COMPLETED');

        
        ###############  RETURN_RECALLED_ITEM 
        
        $content = 
q{<p>Datum: <<today>></p>

<p>Guten Tag <<borrowers.firstname>> <<borrowers.surname>>,</p>

<p>Ihre Bibliothek bittet um eine schnellere Rückgabe des folgenden Mediums: <<biblio.title>> / <<biblio.author>> (Medium: <<items.barcode>>).</p>

<p>Die Leihfrist wurde durch die Bibliothek verkürzt und läuft nun bis zum <<issues.date_due>>. Bitte geben Sie das Medium vor Ende der Leihfrist zurück.</p>

<p>
Vielen Dank.<br>
Ihr Bibliotheksteam<br>
<<branches.branchname>></p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Rückgabe zurückgerufener Medien','Rückruf eines ausgeliehenen Mediums', 'circulation', 'RETURN_RECALLED_ITEM');


        ###############  PICKUP_RECALLED_ITEM 

        $content = 
q{<p>Datum: <<today>></p>

<p>Guten Tag <<borrowers.firstname>> <<borrowers.surname>>,</p>

<p>Sie haben um Rückruf des folgenden Mediums gebeten: <<biblio.title>> / <<biblio.author>> (Medium: <<items.barcode>>).</p>

<p>Das Medium wurde zurückgegeben und ist jetzt für Sie abholbereit in <<recalls.pickup_library_id>></p>

<p>Bitte holen Sie das Medium bis <<recalls.expiration_date>> ab.</p>

<p>
Vielen Dank.<br>
Ihr Bibliotheksteam<br>
<<branches.branchname>></p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Zurückgerufenes Medium bereit zur Abholung','Zurückgerufenes Medium wartet auf Abholung', 'circulation', 'PICKUP_RECALLED_ITEM');


        ###############  RECALL_REQUESTER_DET 

        $content = 
q{Datum: <<today>><br /><br />

Rückruf abholbereit in <br />
<<branches.branchname>><br />
für <<borrowers.surname>>, <<borrowers.firstname>> <br />
(<<borrowers.cardnumber>>)<br />
Tel: <<borrowers.phone>> <br />
Adresse:<br />
<<borrowers.address>> <<borrowers.streetnumber>>, <br>
<<borrowers.address2>>, <br />
<<borrowers.city>> <<borrowers.zipcode>> <br />
Email: <<borrowers.email>><br /><br />

Zurückgerufenes Medium:<br />
<<biblio.title>> von <<biblio.author>><br />
Barcode: <<items.barcode>><br />
Signatur: <<items.itemcallnumber>><br />
Wartet seit: <<recalls.waiting_date>><br />
Hinweise: <<recalls.notes>><br />
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Details des zurückrufenden Benutzers','Rückruf durch Benutzer', 'circulation', 'RECALL_REQUESTER_DET');


        ###############  WELCOME 

        $content = 
q{[% USE Koha %]
<p>Guten Tag [% borrower.title %] [% borrower.firstname %] [% borrower.surname %],<br /><br />

herzlich willkommen bei der [% IF Koha.Preference('LibraryName') %][% Koha.Preference('LibraryName') %][% ELSE %] Bibliothek[% END %]!</p>

<p>In unserem <a href='[% Koha.Preference('OPACBaseURL') %]'>öffentlichen Online-Katalog (OPAC)</a> finden Sie unsere Medien und Angebote.</p>

<p>Ihre neue Bibliotheksausweisnummer ist:  [% borrower.cardnumber %]</p>

<p>Melden Sie sich gerne bei uns, wenn Fragen oder Probleme auftauchen.</p>

<p>Viel Spaß beim Stöbern!<br /><br />

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Willkommen für neue Benutzer','Willkommen in Ihrer Bibliothek', 'members', 'WELCOME');


        ###############  2FA_DISABLE 

        $content = 
q{[% USE Koha %]
<p>Guten Tag [% borrower.firstname %] [% borrower.surname %],</p>

<p>hiermit teilen wir Ihnen mit, dass die Zweifaktorauthentifizierung für Ihr Benutzerkonto deaktiviert wurde.</p>

<p>Wenn Sie die Deaktivierung nicht selbst beantragt oder vorgenommen haben, könnte es sein, dass Unberechtigte Zugriff auf Ihre Kontodaten haben! <br />
Bitte melden Sie sich in diesem Fall unbedingt schnellstmöglich bei uns.</p>

<p>Mit freundlichen Grüßen<br /><br />

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Deaktivierungsbestätigung der Zweifaktorauthentifizierung','Zweifaktorauthentifizierung für Ihren Biblioliotheksaccount wurde deaktiviert', 'members', '2FA_DISABLE');


        ###############  2FA_ENABLE 

        $content = 
q{[% USE Koha %]
<p>Guten Tag [% borrower.firstname %] [% borrower.surname %],</p>

<p>hiermit teilen wir Ihnen mit, dass die Zweifaktorauthentifizierung für Ihr Benutzerkonto aktiviert wurde.</p>

<p>Wenn Sie die Aktivierung nicht selbst beantragt oder vorgenommen haben, könnte es sein, dass Unberechtigte Zugriff auf Ihre Kontodaten haben! <br />
Bitte melden Sie sich in diesem Fall unbedingt schnellstmöglich bei uns.</p>

<p>Mit freundlichen Grüßen<br /><br />

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Aktivierungsbestätigung der Zweifaktorauthentifizierung','Zweifaktorauthentifizierung für Ihren Biblioliotheksaccount wurde aktiviert', 'members', '2FA_ENABLE');


        ###############  STAFF_PASSWORD_RESET 

        $content = 
q{[% USE Koha %]
<p>Guten Tag,</p>

<p>das Passwort für das Benutzerkonto <strong> <<user>> </strong> wurde zurückgesetzt.</p>

<p>Bitte erstellen Sie ein neues Passwort mit dem folgenden Link:</p>

<a href=\"<<passwordreseturl>>\"><<passwordreseturl>></a>

<p>Dieser Link ist 5 Tage ab Zugang dieser Mailbenachrichtigung anklickbar. Nach Ablauf der 5 Tage wird der Link deaktiviert. Falls Sie nach 5 Tagen noch nicht Ihr Passwort geändert haben, müssen Sie erneut um Zurücksetzung Ihres Passworts bitten.</p>

<p>Vielen Dank und viele Grüße

<br /><br />

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Online-Passwort zurückgesetzt','Online-Passwort Ihres Biblioliotheksaccount wurde zurückgesetzt', 'members', 'STAFF_PASSWORD_RESET');


        ###############  OVERDUE_FINE_DESC 

        $content = 
q{[% item.biblio.title %] [% checkout.date_due | $KohaDates %]};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,0,$content,'Gebührenbeschreibung für überfälliges Medium','Overdue item fine description', 'circulation', 'OVERDUE_FINE_DESC');


        ###############  NEW_CURBSIDE_PICKUP 

        $content = 
q{[% USE Koha %]
<p>Guten Tag,</p>

<p>Ihre Bestellung für den Abholservice für [% branch.branchname %]", "[%- USE KohaDates -%]\n[%- SET cp = curbside_pickup -%] wurde terminiert.</p>
<p>Bitte holen Sie Ihre Medien am [% cp.scheduled_pickup_datetime | $KohaDates with_hours => 1 %] in [% cp.library.branchname %] ab. Alle Vormerkungen, die für Sie zurückgelegt wurden, werden der Abholung beigelegt.</p>

<p>Momentan betrifft das folgende Vormerkungen:</p>

[%- FOREACH h IN cp.patron.holds %]<br />[%- IF h.branchcode == cp.branchcode && h.found == 'W' %]<br /> [% h.biblio.title %], [% h.biblio.author %] ([% h.item.barcode %])<br />[%- END %][%- END %]

<p>Wenn Sie am Ort der Abholung angekommen sind, rufen Sie bitte kurz bei Ihrer Bibliothek an oder melden sich mit Ihrem Bibliothekskonto an und klicken auf “Bibliotheksmitarbeiter benachrichtigen”, damit die Bibliothek über Ihre Ankunft informiert ist.</p>

<p>Vielen Dank und viele Grüße<br /><br /> 

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Neue Abholung','Termin zur Abholung eingericht', 'reserves', 'NEW_CURBSIDE_PICKUP');


        ###############  HOLD_CHANGED 

        $content = 
q{Für das Medium <<biblio.title>> (<<items.barcode>>) wurde die wartende Vormerkung storniert. Die nächste wartende Vormerkung auf dieses Medium ist von  <<borrowers.firstname>> <<borrowers.surname>> (<<borrowers.cardnumber>>). 

Bitte ziehen Sie das Medium aus dem Abholregal und geben es erneut zurück, um die nächste Vormerkung auf “Abholbereit” zu setzen und ggf. die Vormerkquittung zu erzeugen.

Titel: <<biblio.title>>

Autor: <<biblio.author>>

Signatur: <<items.itemcallnumber>>

Abholstandort: <<branches.branchname>>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,0,$content,'Stornierte Vormerkung verfügbar für nächsten Benutzer','Stornierte Vormerkung für nächsten Benutzer zurücklegen', 'reserves', 'HOLD_CHANGED');


        ###############  2FA_OTP_TOKEN 

        $content = 
q{[% USE Koha %]
<p>Guten Tag [% borrower.firstname %] [% borrower.surname %] ([% borrower.cardnumber %]),</p>

<p>Ihr Token für die Authentifizierung lautet: [% otp_token %]</p>

<p>Dieses Token ist für eine Minute gültig und läuft dann ab.</p>

<p>Mit freundlichen Grüßen<br /><br />

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Token für Zweifaktorauthentifizierung','Token für Zweifaktorauthentifizierung', 'members', '2FA_OTP_TOKEN');


        ###############  RECEIPT (POS)

        $content = 
q{[% USE KohaDates %]
[% USE Branches %]
[% USE Price %]
[% PROCESS 'accounts.inc' %]
<table>
[% IF ( LibraryName ) %]
	<tr>
		<th colspan='2' class='centerednames'>
			<h3>[% LibraryName | html %]</h3>
		</th>
	</tr>
[% END %]
	<tr>
		<th colspan='2' class='centerednames'>
			<h2>[% Branches.GetName( credit.branchcode ) | html %]</h2>
		</th>
	</tr>
	<tr>
		<th colspan='2' class='centerednames'>
			<h3>[% credit.date | $KohaDates %]</h3>
		</th>
	</tr>
	<tr>
		<td>Transaktions-ID: </td>
		<td>[% credit.accountlines_id %]</td>
	</tr>
	<tr>
		<td>Mitarbeiter-ID: </td>
		<td>[% credit.manager_id %]</td>
	</tr>
	<tr>
		<td>Zahlungsart: </td>
		<td>[% credit.payment_type %]</td>
	</tr>
	<tr></tr>
	<tr>
		<th colspan='2' class='centerednames'>
			<h2><u>Quittung für Zahlung</u></h2>
		</th>
	</tr>
	<tr></tr>
	<tr>
		<th>Gebührenart</th>
		<th>Höhe</th>
	</tr>
	[% FOREACH debit IN credit.debits %]
    <tr>
		<td>[% PROCESS account_type_description account=debit %]</td>
        <td>[% debit.amount * -1 | $Price %]</td>
	</tr>
	[% END %]
	<tfoot>
		<tr class='highlight'>
			<td>Total: </td>    
			<td>[% credit.amount * -1| $Price %]</td>
		</tr>
		<tr>
			<td>Eingenommen: </td>
			<td>[% collected | $Price %]</td>
		</tr>
		<tr>
			<td>Änderung: </td>
			<td>[% change | $Price %]</td>
		</tr>
	</tfoot>
</table>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Kassenbeleg (POS)','Kassenbeleg (POS)', 'pos', 'RECEIPT');


        ###############  ILL_REQUEST_UPDATE 

        $content = 
q{[% USE Koha %]
<p>Guten Tag [% borrower.firstname %] [% borrower.surname %],</p>

<p>für Ihre Fernleihbestellung mit der Bestellnr. [% illrequest.illrequest_id %] (Titel: [% ill_bib_title %] von [% ill_bib_author %]) wurde eine Änderung der Bestellung vorgenommen.</p>
<p>Folgende Daten wurden geändert:<br />[% additional_text %]</p>

<p>Viele Grüße<br /><br /> 

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Änderung Fernleihbestellung','Änderung Ihrer Fernleihbestellung', 'ill', 'ILL_REQUEST_UPDATE');


        ###############  OPAC_REG 

        $content = 
q{<h3>Neue OPAC-Selbstregistrierung</h3>
<p><h4>Selbstregistrierung vorgenommen durch:</h4>
<ul>
<li>[% borrower.firstname %] [% borrower.surname %]</li>
[% IF borrower.cardnumber %]<li>Ausweisnummer: [% borrower.cardnumber %]</li>[% END %]
[% IF borrower.email %]<li>Email: [% borrower.email %]</li>[% END %]
[% IF borrower.phone %]<li>Tel.: [% borrower.phone %]</li>[% END %]
[% IF borrower.mobile %]<li>Mobil: [% borrower.mobile %]</li>[% END %]
[% IF borrower.fax %]<li>Fax: [% borrower.fax %]</li>[% END %]
[% IF borrower.emailpro %]<li>Zweite Emailadresse: [% borrower.emailpro %]</li>[% END %]
[% IF borrower.phonepro %]<li>Zweite Tel.Nr.:[% borrower.phonepro %]</li>[% END %]
[% IF borrower.branchcode %]<li>Heimatbibliothek: [% borrower.branchcode %]</li>[% END %]
[% IF borrower.categorycode %]<li>Benutzertyp: [% borrower.categorycode %]</li>[% END %]
</ul>
</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Neue OPAC-Selbstregistrierung','Neue OPAC-Selbstregistrierung', 'members', 'OPAC_REG');


        ###############  PASSWORD_CHANGE 

        $content = 
q{[% USE Koha %]
<p>Guten Tag [% borrower.firstname %] [% borrower.surname %],</p>

<p>Ihr Passwort wurde geändert. Wenn Sie das Passwort nicht selbst geändert (oder die Änderung beauftragt) haben, melden Sie sich bitte beim Team der Bibliothek.</p>

<p>Viele Grüße<br /><br /> 

Ihr Bibliotheksteam
[% IF Koha.Preference('LibraryName') %]<br />[% Koha.Preference('LibraryName') %][% END %]</p>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Passwortänderung','Ihr Passwort wurde geändert', 'members', 'PASSWORD_CHANGE');


        ###############  ACCOUNTS_SUMMARY 

        $content = 
q{[% USE Branches %]
[% USE Koha %]
[% USE KohaDates %]
[% USE Price %]
[% PROCESS 'accounts.inc' %]
<table>
  [% IF ( Koha.Preference('LibraryName') ) %]
    <tr>
      <th colspan='4' class='centerednames'>
        <h1>[% Koha.Preference('LibraryName') | html %]</h1>
      </th>
    </tr>
  [% END %]

  <tr>
    <th colspan='4' class='centerednames'>
      <h2>[% Branches.GetName( borrower.branchcode ) | html %]</h2>
    </th>
  </tr>

  <tr>
    <th colspan='4' class='centerednames'>
      <h3>Ausstehend</h3>
    </th>
  </tr>

  <tr>
    <th colspan='4' class='centerednames'>
      <h4>Gebühren</h4>
    </th>
  </tr>
  [% IF borrower.account.outstanding_debits.total_outstanding %]
  <tr>
    <th>Datum</th>
    <th>Gebühr</th>
    <th>Höhe</th>
    <th>Ausstehend</th>
  </tr>
  [% FOREACH debit IN borrower.account.outstanding_debits %]
  <tr>
    <td>[% debit.date | $KohaDates %]</td>
    <td>
      [% PROCESS account_type_description account=debit %]
      [%- IF debit.description %], [% debit.description | html %][% END %]
    </td>
    <td class='debit'>[% debit.amount | $Price %]</td>
    <td class='debit'>[% debit.amountoutstanding | $Price %]</td>
  </tr>
  [% END %]
  [% ELSE %]
  <tr>
    <td colspan='4'>Sie haben derzeit keine ausstehenden Gebühren.</td>
  </tr>
  [% END %]

  <tr>
    <th colspan='4' class='centerednames'>
      <h4>Gutschriften</h4>
    </th>
  </tr>
  [% IF borrower.account.outstanding_credits.total_outstanding %]
  <tr>
    <th>Datum</th>
    <th>Gutschrift</th>
    <th>Höhe</th>
    <th>Ausstehend</th>
  </tr>
  [% FOREACH credit IN borrower.account.outstanding_credits %]
  <tr>
    <td>[% credit.date | $KohaDates %]</td>
    <td>
      [% PROCESS account_type_description account=credit %]
      [%- IF credit.description %], [% credit.description | html %][% END %]
    </td>
    <td class='credit'>[% credit.amount *-1 | $Price %]</td>
    <td class='credit'>[% credit.amountoutstanding *-1 | $Price %]</td>
  </tr>
  [% END %]
  [% ELSE %]
  <tr>
    <td colspan='4'>Sie haben keine ausstehenden Gutschriften.</td>
  </tr>
  [% END %]

  <tfoot>
    <tr>
      <td colspan='3'>
        [% IF borrower.account.balance < 0 %]
          Gesamtbetrag Gutschriften zum [% today | $KohaDates %]:
        [% ELSE %]
          Gesamtbetrag ausstehende Gebühren zum [% today | $KohaDates %]:
        [% END %]
      </td>
      [% IF ( borrower.account.balance <= 0 ) %]<td class='credit'>[% borrower.account.balance * -1 | $Price %]</td>
      [% ELSE %]<td class='debit'>[% borrower.account.balance | $Price %]</td>[% END %]
    </tr>
  </tfoot>
</table>
};

        $dbh->do(q{UPDATE `letter` SET `is_html` = ?, `content` = ?, `name` = ?, `title` = ? WHERE `module` = ? AND `code` = ?},undef,1,$content,'Quittung Kontostand','Quittung Kontostand', 'members', 'ACCOUNTS_SUMMARY');

    },
};
