#!/usr/bin/env bash

SCRIPTS_ROOT=/Users/enis.inan/GitHub/scripts
TICKET_NUMBER="PA-1697"
source "${SCRIPTS_ROOT}/${TICKET_NUMBER}/helpers.sh"

INIT_PA_COMPONENTS="${SCRIPTS_ROOT}/${TICKET_NUMBER}/init-pa-components.sh"
PA_BRANCH=1.10.x

reset_repo "puppet-agent" "${PA_BRANCH}"

${INIT_PA_COMPONENTS}
