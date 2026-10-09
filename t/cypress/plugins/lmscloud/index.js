/**
 * LMSCloud Cypress tasks
 *
 * Registered on top of the community tasks by cypress.lmscloud.config.ts, so
 * no community plugin file needs to change. Raw SQL lives here only for data
 * that has no REST endpoint: LMSCloud-only tables and the cleanup gaps of the
 * community helpers.
 *
 * @module lmscloud-cypress-plugins
 */

const { query } = require("../db.js");
const { deleteSampleObjects } = require("../insertData.js");
const { getBasicAuthHeader } = require("../auth.js");

/**
 * Collects the values of one object type from the shapes the community
 * insert helpers return, e.g. `{ patron }`, `{ items: [...] }` or `{ hold, patron }`.
 *
 * @param {Array<Object>} allObjects
 * @param {Array<string>} keys - the singular and plural key of the type
 * @returns {Array<Object>}
 */
function collect(allObjects, keys) {
    return allObjects.flatMap(objects =>
        keys.flatMap(key => {
            const value = objects[key];
            if (!value) return [];
            return Array.isArray(value) ? value : [value];
        })
    );
}

/**
 * Runs `sql` with its single `IN (?)` expanded to `ids`; does nothing for an empty list.
 *
 * @param {string} sql
 * @param {Array} ids
 * @returns {Promise}
 */
function deleteIn(sql, ids) {
    if (!ids.length) return Promise.resolve();
    return query({
        sql: sql.replace("IN (?)", `IN (${ids.map(() => "?").join(",")})`),
        values: ids,
    });
}

/**
 * Deletes test objects like the community deleteSampleObjects, after first
 * removing what that helper leaves behind or trips over: the circulation
 * history and bookings of the given items, the account lines and ILL requests of the given
 * patrons, and afterwards the patron categories insertSamplePatron created.
 *
 * @param {Object|Array<Object>} allObjects - results of the community insert helpers
 * @returns {Promise<boolean>}
 */
async function lmsDeleteSampleObjects(allObjects) {
    if (!Array.isArray(allObjects)) allObjects = [allObjects];

    const item_ids = collect(allObjects, ["item", "items"]).map(i => i.item_id);
    const patron_ids = collect(allObjects, ["patron", "patrons"]).map(
        p => p.patron_id
    );
    const categories = collect(allObjects, ["patron_category"]).map(
        c => c.patron_category_id
    );

    for (const table of [
        "issues",
        "old_issues",
        "reserves",
        "old_reserves",
        "branchtransfers",
    ]) {
        await deleteIn(
            `DELETE FROM ${table} WHERE itemnumber IN (?)`,
            item_ids
        );
    }
    await deleteIn("DELETE FROM bookings WHERE item_id IN (?)", item_ids);
    for (const table of [
        "issues",
        "old_issues",
        "reserves",
        "old_reserves",
        "accountlines",
        "illrequests",
    ]) {
        await deleteIn(
            `DELETE FROM ${table} WHERE borrowernumber IN (?)`,
            patron_ids
        );
    }

    await deleteSampleObjects(allObjects);
    await deleteIn(
        "DELETE FROM categories WHERE categorycode IN (?)",
        categories
    );
    return true;
}

/**
 * Adds an overdue claim to a checkout's claim history; only the overdue
 * notices cron writes these otherwise.
 *
 * @param {Object} params
 * @param {number} params.checkout_id
 * @param {number} [params.claim_level=1]
 * @returns {Promise<boolean>}
 */
async function lmsInsertOverdueClaim({ checkout_id, claim_level = 1 }) {
    await query({
        sql: "INSERT INTO overdue_issues (issue_id, claim_level, claim_time) VALUES (?, ?, NOW())",
        values: [checkout_id, claim_level],
    });
    return true;
}

/**
 * @param {Object} params
 * @param {number} params.checkout_id
 * @returns {Promise<number>} the number of claims in the checkout's history
 */
async function lmsCountOverdueClaims({ checkout_id }) {
    const rows = await query({
        sql: "SELECT COUNT(*) AS n FROM overdue_issues WHERE issue_id = ?",
        values: [checkout_id],
    });
    return rows[0].n;
}

/**
 * Creates an LMSCloud cash register managed by a staff user. With
 * PermitConcurrentCashRegisterUsers off, a managed register counts as the
 * manager's opened register.
 *
 * @param {Object} params
 * @param {string} params.name - cash_register_definition.name
 * @param {string} params.manager_userid - borrowers.userid of the manager
 * @param {string} [params.library_id=""] - the register's library
 * @returns {Promise<boolean>}
 */
async function lmsInsertCashRegister({
    name,
    manager_userid,
    library_id = "",
}) {
    await query({
        sql: "INSERT INTO cash_register_definition (name, branchcode, manager_id, no_branch_restriction) SELECT ?, ?, borrowernumber, 1 FROM borrowers WHERE userid = ?",
        values: [name, library_id, manager_userid],
    });
    return true;
}

/**
 * Makes a library a bookmobile station of another library; the mobilebranch
 * column is LMSCloud-only and has no REST endpoint.
 *
 * @param {Object} params
 * @param {string} params.library_id - the station
 * @param {string|null} params.mobilebranch - the library it belongs to, null to unset
 * @returns {Promise<boolean>}
 */
async function lmsSetMobileBranch({ library_id, mobilebranch }) {
    await query({
        sql: "UPDATE branches SET mobilebranch = ? WHERE branchcode = ?",
        values: [mobilebranch, library_id],
    });
    return true;
}

/**
 * Removes an LMSCloud cash register together with its managers and bookings.
 *
 * @param {Object} params
 * @param {string} params.name - cash_register_definition.name
 * @returns {Promise<boolean>}
 */
async function lmsDeleteCashRegister({ name }) {
    for (const table of ["cash_register_account", "cash_register_manager"]) {
        await query({
            sql: `DELETE t FROM ${table} t JOIN cash_register_definition d ON d.id = t.cash_register_id WHERE d.name = ?`,
            values: [name],
        });
    }
    await query({
        sql: "DELETE FROM cash_register_definition WHERE name = ?",
        values: [name],
    });
    return true;
}

/**
 * @param {Object} params
 * @param {number} params.accountlines_id
 * @returns {Promise<Array<Object>>} the LMSCloud cash register bookings of an account line
 */
async function lmsCashRegisterBookings({ accountlines_id }) {
    return query({
        sql: "SELECT d.name AS register, a.action, a.booking_amount FROM cash_register_account a JOIN cash_register_definition d ON d.id = a.cash_register_id WHERE a.accountlines_id = ?",
        values: [accountlines_id],
    });
}

/**
 * Deletes system preferences that are not part of the installer, such as
 * LMSCloud's hidden preferences, after a test created them. Blank them with
 * set_syspref first so no cached value outlives the row.
 *
 * @param {Object} params
 * @param {Array<string>} params.names
 * @returns {Promise<boolean>}
 */
async function lmsDeleteSysprefs({ names }) {
    await deleteIn(
        "DELETE FROM systempreferences WHERE variable IN (?)",
        names
    );
    return true;
}

/**
 * @param {Object} params
 * @param {Array<string>} params.names
 * @returns {Promise<Object>} map of preference name to its value, null when the row does not exist
 */
async function lmsGetSysprefs({ names }) {
    const rows = await query({
        sql: `SELECT variable, value FROM systempreferences WHERE variable IN (${names.map(() => "?").join(",")})`,
        values: names,
    });
    return Object.fromEntries(
        names.map(name => [
            name,
            rows.find(r => r.variable === name)?.value ?? null,
        ])
    );
}

/**
 * Reads a biblio's MARC record, lets `change` modify it, and stores it back
 * through the REST API. The community API client only returns parsed bodies
 * for application/json, so MARC-in-JSON needs its own requests.
 *
 * @param {Object} params
 * @param {number} params.biblio_id
 * @param {Function} params.change - receives the MARC-in-JSON record and modifies it in place
 * @param {string} params.baseUrl
 * @param {string} params.authHeader
 * @returns {Promise<boolean>}
 */
async function updateMarcRecord({ biblio_id, change, baseUrl, authHeader }) {
    const url = `${baseUrl}/api/v1/biblios/${biblio_id}`;
    const response = await fetch(url, {
        headers: {
            Accept: "application/marc-in-json",
            Authorization: authHeader,
        },
    });
    if (!response.ok) {
        throw new Error(`GET ${url}: ${response.status}`);
    }
    const record = await response.json();
    change(record);
    const update = await fetch(url, {
        method: "PUT",
        headers: {
            "Content-Type": "application/marc-in-json",
            Accept: "application/json",
            Authorization: authHeader,
        },
        body: JSON.stringify(record),
    });
    if (!update.ok) {
        throw new Error(`PUT ${url}: ${update.status} ${await update.text()}`);
    }
    return true;
}

/**
 * Appends a field to a biblio's MARC record.
 *
 * @param {Object} params
 * @param {number} params.biblio_id
 * @param {Object} params.field - a MARC-in-JSON field, e.g. { 856: { ind1, ind2, subfields } }
 * @returns {Promise<boolean>}
 */
function lmsAddMarcField({ field, ...params }) {
    return updateMarcRecord({
        ...params,
        change: record => record.fields.push(field),
    });
}

/**
 * Sets a subfield on the first occurrence of a data field, replacing any
 * existing subfields with the same code.
 *
 * @param {Object} params
 * @param {number} params.biblio_id
 * @param {string} params.tag - e.g. "942"
 * @param {string} params.code - subfield code
 * @param {string} params.value
 * @returns {Promise<boolean>}
 */
function lmsSetMarcSubfield({ tag, code, value, ...params }) {
    return updateMarcRecord({
        ...params,
        change: record => {
            const field = record.fields.find(f => f[tag]);
            if (!field) {
                throw new Error(
                    `No ${tag} field in record ${params.biblio_id}`
                );
            }
            const subfields = field[tag].subfields.filter(sf => !(code in sf));
            subfields.push({ [code]: value });
            field[tag].subfields = subfields;
        },
    });
}

/**
 * Registers the LMSCloud tasks.
 *
 * @param {Function} on - Cypress plugin registration function
 * @param {Object} config - the resolved Cypress configuration
 */
module.exports = (on, config) => {
    const baseUrl = config.baseUrl;
    const authHeader = getBasicAuthHeader(
        config.env.apiUsername,
        config.env.apiPassword
    );
    on("task", {
        lmsAddMarcField(args) {
            return lmsAddMarcField({ ...args, baseUrl, authHeader });
        },
        lmsSetMarcSubfield(args) {
            return lmsSetMarcSubfield({ ...args, baseUrl, authHeader });
        },
        lmsDeleteSampleObjects,
        lmsInsertOverdueClaim,
        lmsCountOverdueClaims,
        lmsInsertCashRegister,
        lmsSetMobileBranch,
        lmsDeleteCashRegister,
        lmsCashRegisterBookings,
        lmsDeleteSysprefs,
        lmsGetSysprefs,
    });
};
