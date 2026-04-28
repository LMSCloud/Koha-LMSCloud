package Koha::Illrequestattribute;

# Backwards-compatibility shim — upstream renamed to Koha::ILL::Request::Attribute in 24.11
# Remove once all LMSCloud code is updated to use Koha::ILL::Request::Attribute

use Koha::ILL::Request::Attribute;
use parent 'Koha::ILL::Request::Attribute';

1;
