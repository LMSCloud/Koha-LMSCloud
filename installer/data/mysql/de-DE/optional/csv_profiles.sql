INSERT IGNORE INTO export_format( profile, description, content, csv_separator, type, used_for )
VALUES ( "Zeitschriftenreklamationen", "Standardprofil für den Export von Heftinformationen für Zeitschriftenreklamationen", "LIEFERANT=aqbooksellers.name|TITEL=subscription.title|HEFTNUMMER=serial.serialseq|VERSPÄTET SEIT=serial.planneddate", ",", "sql", "late_issues" );
