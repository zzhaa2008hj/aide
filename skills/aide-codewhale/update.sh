#!/usr/bin/env bash
# wrapper — redirects to aide-core/scripts/update-codewhale.sh
exec bash -c "$(curl -sSL https://raw.githubusercontent.com/zzhaa2008hj/aide/${AIDE_REF:-master}/aide-core/scripts/update-codewhale.sh)" "$@"
