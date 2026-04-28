package Koha::Illcomment;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Comment in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Comment

use Koha::ILL::Comment;
use parent 'Koha::ILL::Comment';

1;
