package Koha::Illrequest::Config;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Request::Config in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Request::Config

use Koha::ILL::Request::Config;
use parent 'Koha::ILL::Request::Config';

1;
