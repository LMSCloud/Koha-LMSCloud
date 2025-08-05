<template>
    <fieldset v-if="visible && hasFields" class="step-block">
        <legend class="step-header">
            {{ stepNumber }}.
            {{ $__("Additional Fields") }}
        </legend>
        <ul
            id="booking_extended_attributes"
            ref="extendedAttributesContainer"
            class="booking-extended-attributes"
        ></ul>
    </fieldset>
</template>

<script>
import { computed, onMounted, onUnmounted, ref, watch } from "vue";
import { $__ } from "../../i18n";

export default {
    name: "BookingAdditionalFields",
    components: {},
    props: {
        visible: {
            type: Boolean,
            default: true,
        },
        stepNumber: {
            type: Number,
            required: true,
        },
        hasFields: {
            type: Boolean,
            default: false,
        },
        extendedAttributes: {
            type: Array,
            default: () => [],
        },
        extendedAttributeTypes: {
            type: Object,
            default: null,
        },
        authorizedValues: {
            type: Object,
            default: null,
        },
    },
    emits: ["fields-ready", "fields-destroyed"],
    setup(props, { emit }) {
        const extendedAttributesContainer = ref(null);
        const additionalFieldsInstance = ref(null);

        // Initialize additional fields when component mounts and data is available
        const initializeAdditionalFields = () => {
            if (!props.visible || !props.hasFields) return;
            if (!props.extendedAttributeTypes || !extendedAttributesContainer.value) return;

            try {
                // Clear any existing content
                if (extendedAttributesContainer.value) {
                    extendedAttributesContainer.value.innerHTML = '';
                }

                // Initialize the patron extended attributes handler
                // This is typically done via a global function in Koha
                if (window.patron_extended_attributes && props.extendedAttributeTypes) {
                    additionalFieldsInstance.value = window.patron_extended_attributes(
                        extendedAttributesContainer.value,
                        props.extendedAttributeTypes,
                        props.authorizedValues || {},
                        props.extendedAttributes || []
                    );
                    
                    emit("fields-ready", additionalFieldsInstance.value);
                }
            } catch (error) {
                console.error("Failed to initialize additional fields:", error);
            }
        };

        // Clean up additional fields
        const destroyAdditionalFields = () => {
            if (additionalFieldsInstance.value && typeof additionalFieldsInstance.value.destroy === 'function') {
                try {
                    additionalFieldsInstance.value.destroy();
                    emit("fields-destroyed");
                } catch (error) {
                    console.error("Failed to destroy additional fields:", error);
                }
            }
            additionalFieldsInstance.value = null;
        };

        // Watch for changes that require re-initialization
        watch(
            () => [props.hasFields, props.extendedAttributeTypes, props.visible],
            () => {
                destroyAdditionalFields();
                if (props.visible && props.hasFields) {
                    // Use nextTick to ensure DOM is updated
                    setTimeout(initializeAdditionalFields, 0);
                }
            },
            { immediate: false }
        );

        onMounted(() => {
            if (props.visible && props.hasFields) {
                initializeAdditionalFields();
            }
        });

        onUnmounted(() => {
            destroyAdditionalFields();
        });

        return {
            extendedAttributesContainer,
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

.booking-extended-attributes {
    list-style: none;
    padding: 0;
    margin: 0;
}

.booking-extended-attributes :deep(.form-group) {
    margin-bottom: 1rem;
}

.booking-extended-attributes :deep(label) {
    font-weight: 500;
    margin-bottom: 0.5rem;
    display: block;
}

.booking-extended-attributes :deep(.form-control) {
    width: 100%;
    padding: 0.375rem 0.75rem;
    font-size: 1rem;
    line-height: 1.5;
    color: #495057;
    background-color: #fff;
    background-clip: padding-box;
    border: 1px solid #ced4da;
    border-radius: 0.25rem;
    transition: border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
}

.booking-extended-attributes :deep(.form-control:focus) {
    color: #495057;
    background-color: #fff;
    border-color: #80bdff;
    outline: 0;
    box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}

.booking-extended-attributes :deep(select.form-control) {
    cursor: pointer;
}

.booking-extended-attributes :deep(textarea.form-control) {
    min-height: 80px;
    resize: vertical;
}
</style>