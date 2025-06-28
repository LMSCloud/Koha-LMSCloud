import HttpClient from "./http-client.js";

import AdditionalFieldsAPIClient from "./additional-fields-api-client.js";
import AVAPIClient from "./authorised-values-api-client.js";

export const APIClient = {
    additional_fields: new AdditionalFieldsAPIClient(HttpClient),
    authorised_values: new AVAPIClient(HttpClient),
};
