class Dialog {
    constructor(options = {}) {}

    setMessage(message) {
        $("#messages").append(
            '<div class="alert alert-info">%s</div>'.format(message)
        );
    }

    setError(error) {
        $("#messages").append(
            '<div class="alert alert-warning">%s</div>'.format(error)
        );
    }
}

class HttpClient {
    constructor(options = {}) {
        this._baseURL = options.baseURL || "";
        this._headers = options.headers || {
            // FIXME we actually need to merge the headers
            "Content-Type": "application/json;charset=utf-8",
            "X-Requested-With": "XMLHttpRequest",
        };
        this.csrf_token = $('meta[name="csrf-token"]').attr("content");
    }

    async _fetchJSON(
        endpoint,
        headers = {},
        options = {},
        return_response = false,
        mark_submitting = false
    ) {
        let res, error;
        //if (mark_submitting) submitting();
        await fetch(this._baseURL + endpoint, {
            ...options,
            headers: { ...this._headers, ...headers },
        })
            .then(response => {
                const is_json = response.headers
                    .get("content-type")
                    ?.includes("application/json");
                if (!response.ok) {
                    return response.text().then(text => {
                        let message;
                        if (text && is_json) {
                            let json = JSON.parse(text);
                            message =
                                json.error ||
                                json.errors.map(e => e.message).join("\n") ||
                                json;
                        } else {
                            message = response.statusText;
                        }
                        throw new Error(message);
                    });
                }
                if (return_response || !is_json) {
                    return response;
                }
                return response.json();
            })
            .then(result => {
                res = result;
            })
            .catch(err => {
                error = err;
                new Dialog().setError(err);
                console.error(err);
            })
            .then(() => {
                //if (mark_submitting) submitted();
            });

        if (error) throw Error(error);

        return res;
    }

    get(params = {}) {
        return this._fetchJSON(params.endpoint, params.headers, {
            ...params.options,
            method: "GET",
        });
    }

    getAll(params = {}) {
        let url =
            params.endpoint +
            "?" +
            new URLSearchParams({
                _per_page: -1,
                ...(params.params && params.params),
                ...(params.query && { q: JSON.stringify(params.query) }),
            });
        return this._fetchJSON(url, params.headers, {
            ...params.options,
            method: "GET",
        });
    }

    post(params = {}) {
        const body = params.body
            ? typeof params.body === "string"
                ? params.body
                : JSON.stringify(params.body)
            : undefined;
        let csrf_token = { "CSRF-TOKEN": this.csrf_token };
        let headers = { ...csrf_token, ...params.headers };
        return this._fetchJSON(
            params.endpoint,
            headers,
            {
                ...params.options,
                body,
                method: "POST",
            },
            false,
            true
        );
    }

    put(params = {}) {
        const body = params.body
            ? typeof params.body === "string"
                ? params.body
                : JSON.stringify(params.body)
            : undefined;
        let csrf_token = { "CSRF-TOKEN": this.csrf_token };
        let headers = { ...csrf_token, ...params.headers };
        return this._fetchJSON(
            params.endpoint,
            headers,
            {
                ...params.options,
                body,
                method: "PUT",
            },
            false,
            true
        );
    }

    delete(params = {}) {
        let csrf_token = { "CSRF-TOKEN": this.csrf_token };
        let headers = { ...csrf_token, ...params.headers };
        return this._fetchJSON(
            params.endpoint,
            headers,
            {
                parseResponse: false,
                ...params.options,
                method: "DELETE",
            },
            true,
            true
        );
    }
}

export default HttpClient;
