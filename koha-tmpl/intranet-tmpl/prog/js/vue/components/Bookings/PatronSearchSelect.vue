<template>
    <div class="form-group">
        <label for="booking_patron">{{ label }}</label>
        <v-select
            v-model="selectedPatron"
            :options="patronOptions"
            :filterable="false"
            :loading="loading"
            :placeholder="placeholder"
            label="label"
            :clearable="true"
            :reset-on-blur="false"
            :reset-on-select="false"
            @search="debouncedPatronSearch"
        >
            <template #no-options>
                <slot name="no-options" :has-searched="hasSearched">Sorry, no matching options.</slot>
            </template>
            <template #spinner>
                <slot name="spinner">Loading...</slot>
            </template>
        </v-select>
    </div>
</template>

<script>
import { computed, ref } from "vue";
import vSelect from "vue-select";
import "vue-select/dist/vue-select.css";
import { processApiError } from "../../utils/apiErrors.js";
import { useBookingStore } from "../../stores/bookingStore";
import { debounce } from "./bookingUtils.mjs";

export default {
    name: "PatronSearchSelect",
    components: {
        vSelect,
    },
    props: {
        modelValue: {
            type: Object, // Assuming patron object structure
            default: null,
        },
        label: {
            type: String,
            required: true,
        },
        placeholder: {
            type: String,
            default: "",
        },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const store = useBookingStore();
        const patronOptions = ref([]);
        const loading = ref(false); // Manage loading state internally
        const hasSearched = ref(false); // Track if user has performed a search

        const selectedPatron = computed({
            get: () => props.modelValue,
            set: value => emit("update:modelValue", value),
        });

        const onPatronSearch = async search => {
            if (!search || search.length < 2) {
                hasSearched.value = false;
                patronOptions.value = [];
                return;
            }

            hasSearched.value = true;
            loading.value = true; // Use internal loading state

            try {
                const data = await store.fetchPatrons(search);
                patronOptions.value = data;
            } catch (error) {
                console.error("Error searching patrons:", processApiError(error));
                patronOptions.value = [];
            } finally {
                loading.value = false; // Use internal loading state
            }
        };

        const debouncedPatronSearch = debounce(onPatronSearch, 100);

        return {
            selectedPatron,
            patronOptions, // Expose internal options
            loading, // Expose internal loading
            hasSearched, // Expose search state
            debouncedPatronSearch, // Expose internal search handler
        };
    },
};
</script>

<style scoped>
/* Add any specific styles for this component if needed */
</style>
