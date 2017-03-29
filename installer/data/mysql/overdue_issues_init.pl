#!/usr/bin/perl
#
# Copyright 2017 LMSCLoud GmbH
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use strict;
use warnings; 

use C4::Context;

my $sth = C4::Context->dbh;

$sth->do("alter table overduerules convert to character set utf8 collate utf8_unicode_ci");

$sth->do("
    INSERT INTO overdue_issues (issue_id,claim_level,claim_time) 
    SELECT i.issue_id, 1, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay1 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = i.branchcode
         AND o.delay1         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay1 DAY) <= CURDATE()
    UNION
    SELECT  i.issue_id, 1, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay1 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = ''
         AND NOT EXISTS (SELECT 1 FROM overduerules WHERE o.categorycode = b.categorycode AND o.branchcode = i.branchcode)
         AND o.delay1         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay1 DAY) <= CURDATE()
") or die "DB ERROR: " . $sth->errstr . "\n";

$sth->do("
    INSERT INTO overdue_issues (issue_id,claim_level,claim_time) 
    SELECT i.issue_id, 2, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay2 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = i.branchcode
         AND o.delay2         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay2 DAY) <= CURDATE()
    UNION
    SELECT  i.issue_id, 2, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay2 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = ''
         AND NOT EXISTS (SELECT 1 FROM overduerules WHERE o.categorycode = b.categorycode AND o.branchcode = i.branchcode)
         AND o.delay2         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay2 DAY) <= CURDATE()
") or die "DB ERROR: " . $sth->errstr . "\n";

$sth->do("
    INSERT INTO overdue_issues (issue_id,claim_level,claim_time) 
    SELECT i.issue_id, 3, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay3 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = i.branchcode
         AND o.delay3         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay3 DAY) <= CURDATE()
    UNION
    SELECT  i.issue_id, 3, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay3 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = ''
         AND NOT EXISTS (SELECT 1 FROM overduerules WHERE o.categorycode = b.categorycode AND o.branchcode = i.branchcode)
         AND o.delay3         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay3 DAY) <= CURDATE()
") or die "DB ERROR: " . $sth->errstr . "\n";

$sth->do("
    INSERT INTO overdue_issues (issue_id,claim_level,claim_time) 
    SELECT i.issue_id, 4, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay4 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = i.branchcode
         AND o.delay4         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay4 DAY) <= CURDATE()
    UNION
    SELECT  i.issue_id, 4, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay4 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = ''
         AND NOT EXISTS (SELECT 1 FROM overduerules WHERE o.categorycode = b.categorycode AND o.branchcode = i.branchcode)
         AND o.delay4         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay4 DAY) <= CURDATE()
") or die "DB ERROR: " . $sth->errstr . "\n";

$sth->do("
    INSERT INTO overdue_issues (issue_id,claim_level,claim_time) 
    SELECT i.issue_id, 5, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay5 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = i.branchcode
         AND o.delay5         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay5 DAY) <= CURDATE()
    UNION
    SELECT  i.issue_id, 5, TIMESTAMP(DATE_ADD(i.date_due,INTERVAL o.delay5 DAY))
    FROM issues i, overduerules o, categories c, borrowers b
    WHERE    i.borrowernumber = b.borrowernumber
         AND b.categorycode   = c.categorycode
         AND c.overduenoticerequired = 1 
         AND b.categorycode   = o.categorycode
         AND o.branchcode     = ''
         AND NOT EXISTS (SELECT 1 FROM overduerules WHERE o.categorycode = b.categorycode AND o.branchcode = i.branchcode)
         AND o.delay5         > 0
         AND DATE_ADD(i.date_due,INTERVAL o.delay5 DAY) <= CURDATE()
") or die "DB ERROR: " . $sth->errstr . "\n";


