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
            :input-id="'booking_patron'"
            @search="debouncedPatronSearch"
        >
            <template #no-options>
                <slot name="no-options" :has-searched="hasSearched"
                    >Sorry, no matching options.</slot
                >
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
import { storeToRefs } from "pinia";
import { debounce } from "./lib/adapters/external-dependents.mjs";

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
        setError: {
            type: Function,
            default: null,
        },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const store = useBookingStore();
        const { loading } = storeToRefs(store);
        const patronOptions = ref([]);
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
            // Store handles loading state through withErrorHandling
            try {
                const data = await store.fetchPatrons(search);
                patronOptions.value = data;
            } catch (error) {
                const msg = processApiError(error);
                console.error("Error searching patrons:", msg);
                if (typeof props.setError === "function") {
                    try {
                        props.setError(msg, "api");
                    } catch (e) {
                        // no-op: avoid breaking search on error propagation
                    }
                }
                patronOptions.value = [];
            }
        };

        const debouncedPatronSearch = debounce(onPatronSearch, 100);

        return {
            selectedPatron,
            patronOptions, // Expose internal options
            loading: computed(() => loading.value.patrons), // Use store loading state
            hasSearched, // Expose search state
            debouncedPatronSearch, // Expose internal search handler
        };
    },
};
</script>
