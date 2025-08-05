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
        };
    },
};
</script>

<style scoped>
.step-block {
    margin-bottom: var(--booking-space-lg);
}

.step-header {
    font-weight: 600;
    font-size: var(--booking-text-lg);
    margin-bottom: calc(var(--booking-space-lg) * 0.75);
    color: var(--booking-neutral-600);
}

.booking-extended-attributes {
    list-style: none;
    padding: 0;
    margin: 0;
}

.booking-extended-attributes :deep(.form-group) {
    margin-bottom: var(--booking-space-lg);
}

.booking-extended-attributes :deep(label) {
    font-weight: 500;
    margin-bottom: var(--booking-space-md);
    display: block;
}

.booking-extended-attributes :deep(.form-control) {
    width: 100%;
    min-width: var(--booking-input-min-width);
    padding: calc(var(--booking-space-sm) * 1.5) calc(var(--booking-space-sm) * 3);
    font-size: var(--booking-text-base);
    line-height: 1.5;
    color: var(--booking-neutral-600);
    background-color: #fff;
    background-clip: padding-box;
    border: var(--booking-border-width) solid var(--booking-neutral-300);
    border-radius: var(--booking-border-radius-sm);
    transition: border-color var(--booking-transition-fast), box-shadow var(--booking-transition-fast);
}

.booking-extended-attributes :deep(.form-control:focus) {
    color: var(--booking-neutral-600);
    background-color: #fff;
    border-color: hsl(var(--booking-info-hue), 70%, 60%);
    outline: 0;
    box-shadow: 0 0 0 0.2rem hsla(var(--booking-info-hue), 70%, 60%, 0.25);
}

.booking-extended-attributes :deep(select.form-control) {
    cursor: pointer;
}

.booking-extended-attributes :deep(textarea.form-control) {
    min-height: calc(var(--booking-space-2xl) * 2.5);
    resize: vertical;
}
</style>