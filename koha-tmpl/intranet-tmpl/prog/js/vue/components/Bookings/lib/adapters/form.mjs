/**
 * Append hidden input fields to a form from a list of entries.
 * Skips undefined/null values.
 *
 * @param {HTMLFormElement} form
 * @param {Array<[string, unknown]>} entries
 */
export function appendHiddenInputs(form, entries) {
    entries.forEach(([name, value]) => {
        if (value === undefined || value === null) return;
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = String(name);
        input.value = String(value);
        form.appendChild(input);
    });
}

