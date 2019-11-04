# SPDX-License-Identifier: BSD-3-Clause

source helpers.sh

cleanup() {
    rm -f prim.ctx template.data template.hash policy.template
    tpm2_flushcontext session.ctx 2>/dev/null || true
    if [ "${1}" != "no-shutdown" ]; then
        shut_down
    fi
    rm -f session.ctx
}
trap cleanup EXIT

start_up

cleanup "no-shutdown"

#
# Restrict the primary object type created under a hierarchy
#

## Create a key template
tpm2_createprimary -C o -c prim.ctx --template-data template.data

cat template.data | openssl dgst -sha256 -binary -out template.hash

## Create the policytemplate
tpm2_startauthsession -S session.ctx -g sha256

tpm2_policytemplate -S session.ctx -L policy.template \
--template-hash template.hash

tpm2_flushcontext session.ctx

## Set the owner hierarchy policy to create primary keys of specific template
tpm2_setprimarypolicy -C o -g sha256 -L policy.template

## Satisfy the policy and create a primary key
tpm2_startauthsession -S session.ctx -g sha256 --policy-session

tpm2_policytemplate -S session.ctx --template-hash template.hash

tpm2_createprimary -C o -c prim2.ctx -P session:session.ctx

tpm2_flushcontext session.ctx

## Attempt to create a primary key with a different template

tpm2_startauthsession -S session.ctx -g sha256 --policy-session

tpm2_policytemplate -S session.ctx --template-hash template.hash

trap - ERR

tpm2_createprimary -C o -G ecc -c prim2.ctx -P session:session.ctx
if [ $? == 0 ];then
  echo "ERROR: Expected tpm2_reateprimary should fail!"
  exit 1
fi

trap onerror ERR

tpm2_flushcontext session.ctx

exit 0