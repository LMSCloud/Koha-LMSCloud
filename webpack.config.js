const { VueLoaderPlugin } = require("vue-loader");
const path = require("path");
const webpack = require("webpack");

const createBaseConfig = (isOpac = false) => ({
    resolve: {
        alias: {
            "@fetch": path.resolve(
                __dirname,
                "koha-tmpl/intranet-tmpl/prog/js/fetch"
            ),
            "@bookingApi": path.resolve(
                __dirname,
                isOpac
                    ? "koha-tmpl/intranet-tmpl/prog/js/modals/place_booking/bookingApi.opac.js"
                    : "koha-tmpl/intranet-tmpl/prog/js/modals/place_booking/bookingApi.js"
            ),
        },
        extensions: [".ts", ".js", ".vue", ".json"], 
    },
    module: {
        rules: [
            {
                test: /\.vue$/,
                loader: "vue-loader",
                exclude: [path.resolve(__dirname, "t/cypress/")],
            },
            {
                test: /\.ts$/,
                loader: "ts-loader",
                options: {
                    appendTsSuffixTo: [/\.vue$/],
                },
                exclude: [
                    /node_modules/,
                    path.resolve(__dirname, "t/cypress/"),
                ],
            },
            {
                test: /\.css$/i,
                use: ["style-loader", "css-loader"],
            },
        ],
    },
    plugins: [
        new VueLoaderPlugin(),
        new webpack.DefinePlugin({
            __VUE_OPTIONS_API__: true,
            __VUE_PROD_DEVTOOLS__: false,
            __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
            __IS_OPAC__: isOpac,
        }),
    ],
    externals: {
        jquery: "jQuery",
        "datatables.net": "DataTable",
        "datatables.net-buttons": "DataTable",
        "datatables.net-buttons/js/buttons.html5": "DataTable",
        "datatables.net-buttons/js/buttons.print": "DataTable",
        "datatables.net-buttons/js/buttons.colVis": "DataTable",
    },
});

module.exports = [
    {
        ...createBaseConfig(false),
        entry: {
            erm: "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/erm.ts",
            preservation:
                "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/preservation.ts",
            "admin/record_sources":
                "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/admin/record_sources.ts",
            acquisitions:
                "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/acquisitions.ts",
        },
        output: {
            filename: "[name].js",
            path: path.resolve(
                __dirname,
                "koha-tmpl/intranet-tmpl/prog/js/vue/dist/"
            ),
            chunkFilename: "[name].[contenthash].js",
            globalObject: "window",
        },
        mode: "development",
    },
    {
        ...createBaseConfig(false),
        experiments: {
            outputModule: true,
        },
        entry: {
            islands: "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/islands.ts",
        },
        output: {
            filename: "[name].esm.js",
            path: path.resolve(
                __dirname,
                "koha-tmpl/intranet-tmpl/prog/js/vue/dist/"
            ),
            chunkFilename: "[name].[contenthash].esm.js",
            globalObject: "window",
            library: {
                type: "module",
            },
        },
        mode: "development",
    },
    {
        ...createBaseConfig(true),
        experiments: {
            outputModule: true,
        },
        entry: {
            islands: "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/islands.ts",
        },
        output: {
            filename: "[name].esm.js",
            path: path.resolve(
                __dirname,
                "koha-tmpl/opac-tmpl/bootstrap/js/vue/dist/"
            ),
            chunkFilename: "[name].[contenthash].esm.js",
            globalObject: "window",
            library: {
                type: "module",
            },
        },
        mode: "development",
    },
];