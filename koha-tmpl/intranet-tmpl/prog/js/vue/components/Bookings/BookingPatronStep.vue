<template>
    <fieldset v-if="visible" class="step-block">
        <legend class="step-header">
            {{ stepNumber }}.
            {{ $__("Select Patron") }}
        </legend>
        <PatronSearchSelect
            v-model="selectedPatron"
            :label="$__('Patron')"
            :placeholder="$__('Search for a patron')"
        >
            <template #no-options="{ hasSearched }">
                {{ hasSearched ? $__("No patrons found.") : $__("Type to search for patrons.") }}
            </template>
            <template #spinner>
                <span class="sr-only">{{ $__("Searching...") }}</span>
            </template>
        </PatronSearchSelect>
    </fieldset>
</template>

<script>
import { computed } from "vue";
import PatronSearchSelect from "./PatronSearchSelect.vue";
import { $__ } from "../../i18n";

export default {
    name: "BookingPatronStep",
    components: {
        PatronSearchSelect,
    },
    props: {
        visible: {
            type: Boolean,
            default: true,
        },
        stepNumber: {
            type: Number,
            required: true,
        },
        modelValue: {
            type: Object,
            default: null,
        },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const selectedPatron = computed({
            get: () => props.modelValue,
            set: (value) => {
                emit("update:modelValue", value);
            },
        });

        return {
            selectedPatron,
            $__,
        };
    },
};
</script>

<style scoped>
.step-block {
    margin-bottom: 1rem;
}

.step-header {
    font-weight: 600;
    font-size: 1.1rem;
    margin-bottom: 0.75rem;
    color: #495057;
}
</style>