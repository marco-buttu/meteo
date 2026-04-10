from typing import Dict, Any


class LegacyCommandError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


def parse_legacy_command(command: str) -> Dict[str, Any]:
    if not command or not command.strip():
        raise LegacyCommandError("INVALID_REQUEST", "Empty command")

    parts = [p.strip() for p in command.split(",")]

    instr = parts[0]

    try:
        if instr == "iwv":
            _check_len(parts, 3)
            return {
                "operation": "legacy_iwv",
                "parameters": {
                    "date": "A" + parts[1],
                    "hour": int(parts[2]),
                },
            }

        elif instr == "opacity":
            _check_len(parts, 4)
            return {
                "operation": "legacy_opacity",
                "parameters": {
                    "date": "A" + parts[1],
                    "hour": int(parts[2]),
                    "freq": float(parts[3]),
                },
            }

        elif instr == "meteo":
            _check_len(parts, 3)
            return {
                "operation": "legacy_meteo",
                "parameters": {
                    "date": "A" + parts[1],
                    "hour": int(parts[2]),
                },
            }

        elif instr == "rain":
            _check_len(parts, 3)
            return {
                "operation": "legacy_rain",
                "parameters": {
                    "date": "A" + parts[1],
                    "hour": int(parts[2]),
                },
            }

        elif instr == "tsys":
            _check_len(parts, 7)
            return {
                "operation": "legacy_tsys",
                "parameters": {
                    "date": "A" + parts[1],
                    "hour": int(parts[2]),
                    "freq": float(parts[3]),
                    "theta": float(parts[4]),
                    "eta": float(parts[5]),
                    "trec": float(parts[6]),
                },
            }

        else:
            raise LegacyCommandError("UNKNOWN_COMMAND", f"Unknown command: {instr}")

    except ValueError as exc:
        raise LegacyCommandError("INVALID_PARAMETER_TYPE", str(exc)) from exc


def _check_len(parts, expected):
    if len(parts) != expected:
        raise LegacyCommandError(
            "INVALID_PARAMETER_COUNT",
            f"Expected {expected - 1} parameters, got {len(parts) - 1}",
        )
