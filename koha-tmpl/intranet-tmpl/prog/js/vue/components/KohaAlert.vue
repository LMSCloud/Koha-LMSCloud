<template>
    <div v-if="show" :class="computedClass" role="alert">
        <slot>{{ message }}</slot>
        <button
            v-if="dismissible"
            type="button"
            class="close"
            aria-label="Close"
            @click="$emit('dismiss')"
        >
            <span aria-hidden="true">&times;</span>
        </button>
    </div>
    <div v-else></div>
</template>

<script>
export default {
    name: "KohaAlert",
    props: {
        show: { type: Boolean, default: true },
        variant: {
            type: String,
            default: "info", // info | warning | danger | success | secondary
        },
        message: { type: String, default: "" },
        dismissible: { type: Boolean, default: false },
        extraClass: { type: String, default: "" },
    },
    computed: {
        computedClass() {
            const base = ["alert", `alert-${this.variant}`];
            if (this.dismissible) base.push("alert-dismissible");
            if (this.extraClass) base.push(this.extraClass);
            return base.join(" ");
        },
    },
};
</script>

