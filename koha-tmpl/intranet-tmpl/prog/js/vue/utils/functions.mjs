/**
 * Generic utility functions for Vue components
 */

/**
 * Creates a debounced version of a function that delays invocation
 * until after `delay` milliseconds have elapsed since the last call.
 *
 * @template {(...args: any[]) => any} T
 * @param {T} fn - The function to debounce
 * @param {number} delay - Delay in milliseconds
 * @returns {(...args: Parameters<T>) => void}
 */
export function debounce(fn, delay) {
    let timeout;
    return function (...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => fn.apply(this, args), delay);
    };
}

/**
 * Creates a throttled version of a function that only invokes
 * at most once per `limit` milliseconds.
 *
 * @template {(...args: any[]) => any} T
 * @param {T} fn - The function to throttle
 * @param {number} limit - Minimum time between invocations in milliseconds
 * @returns {(...args: Parameters<T>) => void}
 */
export function throttle(fn, limit) {
    let inThrottle;
    return function (...args) {
        if (!inThrottle) {
            fn.apply(this, args);
            inThrottle = true;
            setTimeout(() => (inThrottle = false), limit);
        }
    };
}
