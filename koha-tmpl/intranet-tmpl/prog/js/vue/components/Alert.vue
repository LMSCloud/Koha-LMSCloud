<template>
    <div
        v-if="show"
        :class="computedClass"
        :role="role || undefined"
        :aria-live="live || undefined"
    >
        <slot>{{ message }}</slot>
        <button
            v-if="dismissible"
            type="button"
            class="btn-close"
            :aria-label="$__('Close')"
            @click="$emit('dismiss')"
        ></button>
    </div>
</template>

<script>
export default {
    name: "AlertMessage",
    props: {
        show: { type: Boolean, default: true },
        variant: {
            type: String,
            default: "info", // info | warning | danger | success | secondary
        },
        message: { type: String, default: "" },
        dismissible: { type: Boolean, default: false },
        extraClass: { type: String, default: "" },
        role: {
            type: String,
            default: null,
            validator: value => ["alert", "status"].includes(value),
        },
        live: {
            type: String,
            default: null,
            validator: value => ["assertive", "polite", "off"].includes(value),
        },
    },
    emits: ["dismiss"],
    computed: {
        /**
         * Build Bootstrap alert classes from presentation props.
         *
         * @returns {string} Space-separated alert classes.
         */
        computedClass() {
            const base = ["alert", `alert-${this.variant}`];
            if (this.dismissible) base.push("alert-dismissible");
            if (this.extraClass) base.push(this.extraClass);
            return base.join(" ");
        },
    },
};
</script>
