const { VueLoaderPlugin } = require("vue-loader");
const path = require("path");
const webpack = require("webpack");

module.exports = {
    entry: {
        erm: "./koha-tmpl/intranet-tmpl/prog/js/vue/modules/erm.ts",
    },
    output: {
        filename: "[name].js",
        path: path.resolve(
            __dirname,
            "koha-tmpl/intranet-tmpl/prog/js/vue/dist/"
        ),
        chunkFilename: "[name].js",
    },
    resolve: {
        alias: {
            // Prevent webpack from trying to compile islands.ts
            "./islands": false,
            "./islands.ts": false,
        },
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
                    transpileOnly: true,
                },
                exclude: [
                    path.resolve(__dirname, "t/cypress/"),
                    /islands\.ts$/,
                ],
            },
            {
                test: /\.css$/,
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
        }),
        new webpack.IgnorePlugin({
            resourceRegExp: /islands\.ts$/,
        }),
    ],
};
