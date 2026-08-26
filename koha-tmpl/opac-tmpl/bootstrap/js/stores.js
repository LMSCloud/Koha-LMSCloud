(function () {
    const app = (window.Koha ??= {});

    const permissions = (app.permissions ??= {});
    app.addPermissions = function (perms) {
        for (const key in perms) {
            if (Object.prototype.hasOwnProperty.call(perms, key)) {
                permissions[key] = perms[key];
            }
        }
    };

    const prefs = (app.prefs = app.prefs || {});
    app.addPrefs = function (sysprefs) {
        for (const key in sysprefs) {
            if (Object.prototype.hasOwnProperty.call(sysprefs, key)) {
                prefs[key] = sysprefs[key];
            }
        }
    };
})();
