package Koha::Illrequestattributes;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Request::Attributes in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Request::Attributes

use Koha::ILL::Request::Attributes;
use parent 'Koha::ILL::Request::Attributes';

1;
