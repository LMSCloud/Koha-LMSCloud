import { reactive, computed } from "vue";

/**
 * Simple error state composable used across booking components.
 * Exposes a reactive error object with message and code, and helpers
 * to set/clear it consistently.
 */
export function useErrorState(initial = {}) {
    const state = reactive({
        message: initial.message || "",
        code: initial.code || null,
    });

    function setError(message, code = "ui") {
        state.message = message || "";
        state.code = message ? code || "ui" : null;
    }

    function clear() {
        state.message = "";
        state.code = null;
    }

    const hasError = computed(() => !!state.message);

    return { error: state, setError, clear, hasError };
}

