-- 
-- Default classification sources and filing rules
-- for Koha.
--
-- Copyright (C) 2011 Magnus Enger Libriotech
--
-- This file is part of Koha.
--
-- Koha is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- Koha is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Koha; if not, see <http://www.gnu.org/licenses>.

-- Reasons for acceptance or rejection of suggestions in acquisitions
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SUGGEST','BSELL','Bestselger');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SUGGEST','SCD','Bibliotekets eksemplar er skadet');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SUGGEST','LCL','Bibliotekets eksemplar er tapt');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SUGGEST','AVILL','Tilgjengelig via fjernlån');

-- availability statuses
INSERT INTO `authorised_values`  (category, authorised_value, lib) VALUES ('LOST','2','Regnes som tapt');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOST','1','Tapt');
INSERT INTO `authorised_values`  (category, authorised_value, lib ) VALUES ('LOST','3','Tapt og erstattet');
INSERT INTO `authorised_values`  (category, authorised_value, lib )VALUES ('LOST','4','Savnet');

-- damaged status of an item
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('DAMAGED','1','Skadet');

-- location qualification for an item, departments are linked by default to items.location
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','FIC','Skjønnlitteratur');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','CHILD','Barneavdelingen');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','DISPLAY','På utstilling');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','NEW','Nyhetshylla');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','STAFF','Ansattes kontor');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','GEN','Samlingen');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','AV','AV-materiale');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','REF','Oppslagsverk');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','CART','Boktralle');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('LOC','PROC','Til klargjøring');

-- collection codes for an item
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('CCODE','FIC','Skjønnlitteratur');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('CCODE','REF','Oppslagsverk');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('CCODE','NFIC','Faglitteratur');

-- withdrawn status of an item, linked to items.withdrawn
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('WITHDRAWN','1','Trukket tilbake');

-- loanability status of an item, linked to items.notforloan
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('NOT_LOAN','-1','I bestilling');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('NOT_LOAN','1','Ikke til utlån');
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('NOT_LOAN','2','Kun til internt bruk');

-- restricted status of an item, linked to items.restricted
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('RESTRICTED','1','Begrenset tilgang');

-- custom borrower notes
INSERT INTO `authorised_values` (category, authorised_value, lib) VALUES ('BOR_NOTES','ADDR','Addresse-noter');

-- OPAC Suggestions reasons
INSERT INTO authorised_values (category,authorised_value,lib,lib_opac) VALUES ('OPAC_SUG','damaged','Eksemplaret på hylla er skadet','Eksemplaret på hylla er skadet');
INSERT INTO authorised_values (category,authorised_value,lib,lib_opac) VALUES ('OPAC_SUG','bestseller','Kommende tittel av populær forfatter','Kommende tittel av populær forfatter');

-- Report groups
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('REPORT_GROUP', 'CIRC', 'Sirkulasjon');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('REPORT_GROUP', 'CAT', 'Katalog');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('REPORT_GROUP', 'PAT', 'Lånere');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('REPORT_GROUP', 'ACQ', 'Innkjøp');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('REPORT_GROUP', 'ACC', 'Gebyrer');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('REPORT_GROUP', 'SER', 'Serials');

-- SIP2 media types
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '000', 'Other');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '001', 'Book');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '002', 'Magazine');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '003', 'Bound journal');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '004', 'Audio tape');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '005', 'Video tape');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '006', 'CD/CDROM');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '007', 'Diskette');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '008', 'Book with diskette');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '009', 'Book with CD');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('SIP_MEDIA_TYPE', '010', 'Book with audio tape');

-- order cancellation reasons
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('ORDER_CANCELLATION_REASON', 0, 'No reason provided');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('ORDER_CANCELLATION_REASON', 1, 'Out of stock');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('ORDER_CANCELLATION_REASON', 2, 'Restocking');

-- Desired formats for requesting new materials
INSERT INTO authorised_values (category, authorised_value, lib, lib_opac) VALUES ('SUGGEST_FORMAT', 'BOOK', 'Book', 'Book');
INSERT INTO authorised_values (category, authorised_value, lib, lib_opac) VALUES ('SUGGEST_FORMAT', 'LP', 'Large print', 'Large print');
INSERT INTO authorised_values (category, authorised_value, lib, lib_opac) VALUES ('SUGGEST_FORMAT', 'EBOOK', 'EBook', 'Ebook');
INSERT INTO authorised_values (category, authorised_value, lib, lib_opac) VALUES ('SUGGEST_FORMAT', 'AUDIOBOOK', 'Audiobook', 'Audiobook');
INSERT INTO authorised_values (category, authorised_value, lib, lib_opac) VALUES ('SUGGEST_FORMAT', 'DVD', 'DVD', 'DVD');

-- return claims
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('RETURN_CLAIM_RESOLUTION', 'RET_BY_PATRON', 'Returned by patron');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('RETURN_CLAIM_RESOLUTION', 'FOUND_IN_LIB',  'Found in library');

-- hold cancellation
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('HOLD_CANCELLATION','NOT_FOUND','Item could not be located on shelves');
INSERT INTO authorised_values (category, authorised_value, lib) VALUES ('HOLD_CANCELLATION','DAMAGED','Item was found to be too damaged to fill hold');
