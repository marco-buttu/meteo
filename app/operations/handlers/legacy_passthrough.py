from app.integrations.atm_ser_adapter import run_atm_ser


def handle_legacy_iwv(params):
    return run_atm_ser("legacy_iwv", params)


def handle_legacy_opacity(params):
    return run_atm_ser("legacy_opacity", params)


def handle_legacy_meteo(params):
    return run_atm_ser("legacy_meteo", params)


def handle_legacy_rain(params):
    return run_atm_ser("legacy_rain", params)


def handle_legacy_tsys(params):
    return run_atm_ser("legacy_tsys", params)
