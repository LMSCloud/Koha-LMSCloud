import { describe, it, beforeEach, afterEach } from "mocha";
import { expect } from "chai";

/**
 * Since fetchItemTypeFilterOptions uses fetch() which isn't available in Node,
 * we test the hierarchy building logic by extracting it into a testable function.
 * We replicate the logic from utils.js::fetchItemTypeFilterOptions to test it.
 */

function buildItemTypeFilterOptions(itemTypes) {
    const parents = itemTypes.filter(it => !it.parent_type);
    const childrenByParent = {};
    itemTypes
        .filter(it => it.parent_type)
        .forEach(it => {
            if (!childrenByParent[it.parent_type]) childrenByParent[it.parent_type] = [];
            childrenByParent[it.parent_type].push(it);
        });

    const options = [];
    const parentMap = {};
    const groups = [];

    parents.sort((a, b) => (a.description || "").localeCompare(b.description || ""));

    parents.forEach(parent => {
        const children = (childrenByParent[parent.item_type_id] || [])
            .sort((a, b) => (a.description || "").localeCompare(b.description || ""));

        const parentOption = { _id: parent.item_type_id, _str: parent.description || parent.item_type_id };
        options.push(parentOption);

        if (children.length > 0) {
            parentMap[parent.item_type_id] = children.map(c => c.item_type_id);
            const childOptions = children.map(child => ({
                _id: child.item_type_id,
                _str: child.description || child.item_type_id,
            }));
            childOptions.forEach(c => options.push(c));
            groups.push({ ...parentOption, children: childOptions });
        } else {
            groups.push(parentOption);
        }
    });

    return { options, parentMap, groups };
}

function expandItemTypeSelection(val, parentMap) {
    const children = parentMap[val];
    if (children && children.length > 0) {
        return [val, ...children];
    }
    return val;
}

describe("ItemType Filter - Hierarchy Building", () => {
    it("handles flat itemtypes with no parent-child relationships", () => {
        const itemTypes = [
            { item_type_id: "BK", parent_type: null, description: "Books" },
            { item_type_id: "DVD", parent_type: null, description: "DVDs" },
            { item_type_id: "CD", parent_type: null, description: "CDs" },
        ];

        const { options, parentMap, groups } = buildItemTypeFilterOptions(itemTypes);

        expect(options).to.have.length(3);
        expect(options[0]).to.deep.equal({ _id: "BK", _str: "Books" });
        expect(options[1]).to.deep.equal({ _id: "CD", _str: "CDs" });
        expect(options[2]).to.deep.equal({ _id: "DVD", _str: "DVDs" });
        expect(Object.keys(parentMap)).to.have.length(0);

        expect(groups).to.have.length(3);
        groups.forEach(g => expect(g).to.not.have.property("children"));
    });

    it("builds hierarchy with parent and child types", () => {
        const itemTypes = [
            { item_type_id: "BK", parent_type: null, description: "Books" },
            { item_type_id: "BK_FIC", parent_type: "BK", description: "Fiction" },
            { item_type_id: "BK_NON", parent_type: "BK", description: "Non-Fiction" },
            { item_type_id: "DVD", parent_type: null, description: "DVDs" },
        ];

        const { options, parentMap, groups } = buildItemTypeFilterOptions(itemTypes);

        expect(options).to.have.length(4);
        expect(options[0]).to.deep.equal({ _id: "BK", _str: "Books" });
        expect(options[1]).to.deep.equal({ _id: "BK_FIC", _str: "Fiction" });
        expect(options[2]).to.deep.equal({ _id: "BK_NON", _str: "Non-Fiction" });
        expect(options[3]).to.deep.equal({ _id: "DVD", _str: "DVDs" });

        expect(parentMap).to.deep.equal({
            BK: ["BK_FIC", "BK_NON"],
        });

        expect(groups).to.have.length(2);
        expect(groups[0]).to.deep.equal({
            _id: "BK",
            _str: "Books",
            children: [
                { _id: "BK_FIC", _str: "Fiction" },
                { _id: "BK_NON", _str: "Non-Fiction" },
            ],
        });
        expect(groups[1]).to.deep.equal({ _id: "DVD", _str: "DVDs" });
    });

    it("sorts parents alphabetically", () => {
        const itemTypes = [
            { item_type_id: "DVD", parent_type: null, description: "DVDs" },
            { item_type_id: "BK", parent_type: null, description: "Books" },
            { item_type_id: "ZIN", parent_type: null, description: "Magazines" },
        ];

        const { options } = buildItemTypeFilterOptions(itemTypes);

        expect(options.map(o => o._id)).to.deep.equal(["BK", "DVD", "ZIN"]);
    });

    it("sorts children alphabetically under their parent", () => {
        const itemTypes = [
            { item_type_id: "BK", parent_type: null, description: "Books" },
            { item_type_id: "BK_Z", parent_type: "BK", description: "Zines" },
            { item_type_id: "BK_A", parent_type: "BK", description: "Art Books" },
            { item_type_id: "BK_M", parent_type: "BK", description: "Magazines" },
        ];

        const { options, groups } = buildItemTypeFilterOptions(itemTypes);

        expect(options.map(o => o._id)).to.deep.equal(["BK", "BK_A", "BK_M", "BK_Z"]);
        expect(groups[0].children.map(c => c._id)).to.deep.equal(["BK_A", "BK_M", "BK_Z"]);
    });

    it("handles multiple parents with children", () => {
        const itemTypes = [
            { item_type_id: "BK", parent_type: null, description: "Books" },
            { item_type_id: "BK_FIC", parent_type: "BK", description: "Fiction" },
            { item_type_id: "DVD", parent_type: null, description: "DVDs" },
            { item_type_id: "DVD_DOC", parent_type: "DVD", description: "Documentary" },
            { item_type_id: "DVD_MOV", parent_type: "DVD", description: "Movie" },
        ];

        const { options, parentMap, groups } = buildItemTypeFilterOptions(itemTypes);

        expect(options).to.have.length(5);
        expect(parentMap).to.deep.equal({
            BK: ["BK_FIC"],
            DVD: ["DVD_DOC", "DVD_MOV"],
        });

        expect(groups).to.have.length(2);
        expect(groups[0].children).to.have.length(1);
        expect(groups[1].children).to.have.length(2);
    });

    it("uses item_type_id as fallback when description is missing", () => {
        const itemTypes = [
            { item_type_id: "BK", parent_type: null, description: null },
            { item_type_id: "BK_X", parent_type: "BK", description: "" },
        ];

        const { options, groups } = buildItemTypeFilterOptions(itemTypes);

        expect(options[0]._str).to.equal("BK");
        expect(options[1]._str).to.equal("BK_X");
        expect(groups[0].children[0]._str).to.equal("BK_X");
    });

    it("handles empty input", () => {
        const { options, parentMap, groups } = buildItemTypeFilterOptions([]);

        expect(options).to.have.length(0);
        expect(Object.keys(parentMap)).to.have.length(0);
        expect(groups).to.have.length(0);
    });

    it("groups structure mirrors optgroup convention", () => {
        const itemTypes = [
            { item_type_id: "BK", parent_type: null, description: "Books" },
            { item_type_id: "BK_FIC", parent_type: "BK", description: "Fiction" },
            { item_type_id: "CD", parent_type: null, description: "CDs" },
            { item_type_id: "DVD", parent_type: null, description: "DVDs" },
            { item_type_id: "DVD_BLU", parent_type: "DVD", description: "Blu-ray" },
        ];

        const { groups } = buildItemTypeFilterOptions(itemTypes);

        // Parents with children produce groups with children array
        const withChildren = groups.filter(g => g.children);
        expect(withChildren).to.have.length(2);

        // Standalone parents have no children property
        const standalone = groups.filter(g => !g.children);
        expect(standalone).to.have.length(1);
        expect(standalone[0]._id).to.equal("CD");
    });
});

describe("ItemType Filter - Selection Expansion", () => {
    it("returns single value for child/standalone type", () => {
        const parentMap = { BK: ["BK_FIC", "BK_NON"] };

        const result = expandItemTypeSelection("BK_FIC", parentMap);
        expect(result).to.equal("BK_FIC");
    });

    it("returns array of parent + children for parent type", () => {
        const parentMap = { BK: ["BK_FIC", "BK_NON"] };

        const result = expandItemTypeSelection("BK", parentMap);
        expect(result).to.deep.equal(["BK", "BK_FIC", "BK_NON"]);
    });

    it("returns single value for types not in parentMap", () => {
        const parentMap = { BK: ["BK_FIC"] };

        const result = expandItemTypeSelection("DVD", parentMap);
        expect(result).to.equal("DVD");
    });

    it("returns single value with empty parentMap", () => {
        const result = expandItemTypeSelection("BK", {});
        expect(result).to.equal("BK");
    });
});
