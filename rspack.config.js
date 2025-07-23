const { VueLoaderPlugin } = require("vue-loader");
//const autoprefixer = require("autoprefixer");
const path = require("path");
const rspack = require("@rspack/core");

// Helper to create base config
const createBaseConfig = (isOpac = false) => ({
    resolve: {
        alias: {
            // Use Vue 3.5 for islands
            "vue": path.resolve(__dirname, "node_modules/vue-3.5"),
            "@fetch": path.resolve(
                __dirname,
                "koha-tmpl/intranet-tmpl/prog/js/fetch"
            ),
            "@bookingApi": path.resolve(
                __dirname,
                isOpac
                    ? "koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/bookingApi.opac.js"
                    : "koha-tmpl/intranet-tmpl/prog/js/vue/components/Bookings/bookingApi.js"
            ),
        },
    },
    module: {
        rules: [
            {
                test: /\.vue$/,
                loader: "vue-loader",
                options: {
                    experimentalInlineMatchResource: true,
                },
                exclude: [path.resolve(__dirname, "t/cypress/")],
            },
            {
                test: /\.ts$/,
                loader: "builtin:swc-loader",
                options: {
                    jsc: {
                        parser: {
                            syntax: "typescript",
                        },
                    },
                },
                exclude: [
                    /node_modules/,
                    path.resolve(__dirname, "t/cypress/"),
                ],
                type: "javascript/auto",
            },
            {
                test: /\.css$/i,
                type: "javascript/auto",
                use: ["style-loader", "css-loader"],
            },
        ],
    },
    plugins: [
        new VueLoaderPlugin(),
        new rspack.DefinePlugin({
            __VUE_OPTIONS_API__: true,
            __VUE_PROD_DEVTOOLS__: false,
            __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
            // Add environment variable for API module selection
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
    // Staff interface ESM config
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
    },
    // OPAC interface config
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
    },
];
