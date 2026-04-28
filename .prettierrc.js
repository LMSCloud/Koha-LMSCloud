module.exports = {
    arrowParens: "avoid",
    trailingComma: "es5",
    tabWidth: 4,
    useTabs: false,
    overrides: [
        {
            files: ["*.js", "*.ts", "*.vue"],
            options: {
                trailingComma: "es5",
                arrowParens: "avoid",
            },
        },
        {
            files: "*.vue",
            options: {
                semi: false,
                tabWidth: 2,
            },
        },
        {
            files: ["*.tt", "*.inc"],
            options: {
                printWidth: 240,
                htmlWhitespaceSensitivity: "strict",
                parser: "template-toolkit",
                plugins: ["@koha-community/prettier-plugin-template-toolkit"],
            },
        },
    ],
};
