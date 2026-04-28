package Koha::Illrequests;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Requests in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Requests

use Koha::ILL::Requests;
use parent 'Koha::ILL::Requests';

1;
