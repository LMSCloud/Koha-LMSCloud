import "dayjs";
declare module "dayjs" {
    interface Dayjs {
        isSameOrBefore(
            date?: import("dayjs").ConfigType,
            unit?: import("dayjs").OpUnitType
        ): boolean;
        isSameOrAfter(
            date?: import("dayjs").ConfigType,
            unit?: import("dayjs").OpUnitType
        ): boolean;
        isBetween(
            a: import("dayjs").ConfigType,
            b: import("dayjs").ConfigType,
            unit?: import("dayjs").OpUnitType,
            inclusivity?: "()" | "[]" | "(]" | "[)"
        ): boolean;
    }
}
