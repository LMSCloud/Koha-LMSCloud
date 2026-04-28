package Koha::Illcomments;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Comments in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Comments

use Koha::ILL::Comments;
use parent 'Koha::ILL::Comments';

1;
