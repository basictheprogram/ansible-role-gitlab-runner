from typing import Any


def first_or_value(value: Any, default: Any = None) -> Any:
    """Return the first element if value is a list or tuple.

    Returns default when value is None or an empty list/tuple.
    Returns value unchanged for all other types.
    """
    if value is None:
        return default
    if isinstance(value, list | tuple):
        return value[0] if value else default
    return value


class FilterModule:
    def filters(self) -> dict[str, Any]:
        return {
            "first_or_value": first_or_value,
        }
