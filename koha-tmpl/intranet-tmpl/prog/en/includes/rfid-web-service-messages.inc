<script type="text/javascript">
    var RFIDWebServiceMessageProvider = {
        GetErrorMessage: function (errorCode,errorMessage,vendorName) {
            if ( errorCode ) {
                if ( errorCode == "MULTIPLE_USER_CARDS_ON_PAD" ) {
                    return _("There are multiple user cards on the RFID pad.");
                }
                else if ( errorCode == "CHECKOUT_NOT_ALLOWED_ITEMS" ) {
                    return _("The following item barcodes on the RFID-Pad are marked as non lendable: ") + errorMessage + ".";
                }
                
                if ( vendorName && vendorName.toLowerCase().includes("easycheck") ) {
                    return this.GetEasyCheckErrorMessage(errorCode,errorMessage);
                }
                return _("The RFID Service returned the following error (code ") + errorCode + _("): ") + errorMessage;
            }
            return _("The RFID Service returned the following error: ") + errorMessage;
        },
        GetRFIDErrorDialogNames: function () {
            return {
                        title:                  _("RFID Error Message"),
                        actionClose:            _("Close")
                    };
        },
        GetRFIDMenuNames: function () {
            return {
                        topLevelMenuEntry:      _("RFID"),
                        menuEntryServiceInfo:   _("RFID-Service Information"),
                        menuEntryServiceTools:  _("RFID-Tools")
                    };
        },
        GetRFIDStatusDialogNames: function () {
            return {
                        title:                  _("RFID WebService Information"),
                        status:                 _("Status"), 
                        statusOk:               _("Service ready"),
                        statusError:            _("Initialization error"),
                        statusNoService:        _("No RFID WebService Information available."),
                        errorCode:              _("Error code"), 
                        errorMessage:           _("Error message"),
                        vendorName:             _("Vendor name"),
                        readerModel:            _("Reader model"),
                        serviceVersion:         _("Service version"),
                        countryId:              _("Country code"),
                        libraryId:              _("Library code"),
                        backwardCompatibility:  _("Compatibility with version"),
                        actionClose:            _("Close")
                    };
        },
        
        GetEasyCheckErrorMessage: function (errorCode,errorMessage) {
            if ( errorCode == "-1001" ) {
                return "Fehler beim Öffnen des Readers. Der Reader ist möglicherweise nicht angeschlossen, oder am falschen COM Port angeschlossen. Es ist auch möglich, dass ein anderes Programm gerade auf den USB o. COM-Port zugreift.";
            }
            else if ( errorCode == "-1002" ) {
                return "Fehler beim Schließen des Readers";
            }
            else if ( errorCode == "-1003" ) {
                return "Reader nicht geöffnet. OpenReader wurde nicht aufgerufen.";
            }
            else if ( errorCode == "-1004" ) {
                return "Es befindet sich kein Transponder im Feld des RFID-Readers.";
            }
            else if ( errorCode == "-1005" ) {
                return "Eines der Medienpakete im Feld des RFID-Readers ist unvollständig.";
            }
            else if ( errorCode == "-1007" ) {
                return "Der RFID-Transponder konnte nicht entsichert werden.";
            }
            else if ( errorCode == "-1008" ) {
                return "Der RFID-Transponder konnte nicht gesichert werden.";
            }
            else if ( errorCode == "-1009" ) {
                return "Fehler beim Beschreiben des Transponders. Der Transponder konnte nicht beschrieben werden.";
            }
            else if ( errorCode == "-1010" ) {
                return "Fehler beim Beschreiben des Medienpakets. Das Medienpaket konnte nicht beschrieben werden.";
            }
            else if ( errorCode == "-1011" ) {
                return "Es befinden sich mehrere RFID-Transponder im Feld des RFID-Readers.";
            }
            else if ( errorCode == "-1012" ) {
                return "Der CountryID auf dem Transponder stimmt nicht mit dem Ländercode in der EasyCheck.ini überein.";
            }
            else if ( errorCode == "-1013" ) {
                return "Die LibraryID auf dem Transponder stimmt nicht mit der LibraryID in der EasyCheck.ini überein.";
            }
            else if ( errorCode == "-1014" ) {
                return "Die berechnete CRC Prüfsumme der Daten stimmt nicht mit der CRC Prüfsumme auf den Transponder überein.";
            }
            else if ( errorCode == "-1015" ) {
                return "Nicht unterstütztes Datenmodell. Das Datenmodell auf dem Chip wird von der Easy- Check.dll nicht erkannt, nicht unterstützt oder der Transponder ist leer.";
            }
            else if ( errorCode == "-1016" ) {
                return "Der ItemStatus auf dem Transponder ist als nicht ausleihbar gekennzeichnet, das Medium kann daher nicht ausgeliehen werden.";
            }
            else if ( errorCode == "-1017" ) {
                return "Der Transponder konnte nicht entsichert oder gesichert werden da auf dem Chip ein Passwortschutz für den Alarm aktiviert ist und das richtige Passwort nicht in der EasyCheck.ini steht.";
            }
            else if ( errorCode == "-1018" ) {
                return "Der Passwortschutz konnte auf dem Transponder nicht gesetzt werden, obwohl das richtige Passwort in der EasyCheck.ini steht.";
            }
            else if ( errorCode == "-1019" ) {
                return "Der Schreibschutz konnte auf dem Transponder nicht gesetzt werden, obwohl dies in der EasyCheck.ini aktiviert wurde.";
            }
            return _("The RFID Service returned the following error (code ") + errorCode + _("): ") + errorMessage;
        }
    };
</script>