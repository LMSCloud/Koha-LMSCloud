import HttpClient from "./http-client";

export class SysprefAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/cgi-bin/koha/svc/config/systempreferences",
        });
    }

    get sysprefs() {
        return {
            get: (variable) =>
                this.get({
                    endpoint: "/?pref=" + variable,
                }),
            update: (variable, value) =>
                this.post({
                    endpoint: "",
                    body: "pref_%s=%s&csrf_token=%s".format(
                        variable,
                        value,
                        csrf_token
                    ),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
        };
    }
}

export default SysprefAPIClient;
