package Koha::Illrequest;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Request in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Request

use Koha::ILL::Request;
use parent 'Koha::ILL::Request';

1;
