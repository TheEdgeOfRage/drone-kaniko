#!/busybox/sh

set -euo pipefail

export PATH=$PATH:/kaniko/
REGISTRY=${PLUGIN_REGISTRY:-index.docker.io}
CONTEXT=${PLUGIN_CONTEXT:-$PWD}
DOCKERFILE=${PLUGIN_DOCKERFILE:-Dockerfile}
CACHE_DIR="--cache-dir=${PLUGIN_CACHE_DIR:-/cache}"

if [[ -n "${PLUGIN_TARGET:-}" ]]; then
    TARGET="--target=${PLUGIN_TARGET}"
fi
if [ -n "${PLUGIN_BUILD_ARGS:-}" ]; then
    BUILD_ARGS=$(echo "${PLUGIN_BUILD_ARGS}" | tr ',' '\n' | while read build_arg; do echo "--build-arg=${build_arg}"; done)
fi
if [ -n "${PLUGIN_BUILD_ARGS_FROM_ENV:-}" ]; then
    BUILD_ARGS_FROM_ENV=$(echo "${PLUGIN_BUILD_ARGS_FROM_ENV}" | tr ',' '\n' | while read build_arg; do echo "--build-arg ${build_arg}=$(eval "echo \$$build_arg")"; done)
fi
if [[ "${PLUGIN_CACHE:-}" == "true" ]]; then
    CACHE="--cache --cache-copy-layers"
fi
if [ -n "${PLUGIN_CACHE_TTL:-}" ]; then
    CACHE_TTL="--cache-ttl=${PLUGIN_CACHE_TTL}"
fi

# auto_tag, if set auto_tag: true, auto generate .tags file
# support format Major.Minor.Release or start with `v`
# docker tags: Major, Major.Minor, Major.Minor.Release and latest
if [[ "${PLUGIN_AUTO_TAG:-}" == "true" ]]; then
    TAG=$(echo "${DRONE_TAG:-}" |sed 's/^v//g')
    part=$(echo "${TAG}" |tr '.' '\n' |wc -l)
    # expect number
    echo ${TAG} |grep -E "[a-z-]" &>/dev/null && isNum=1 || isNum=0

    if [ ! -n "${TAG:-}" ];then
        echo "latest" > .tags
    elif [ ${isNum} -eq 1 -o ${part} -gt 3 ];then
        echo "${TAG},latest" > .tags
    else
        major=$(echo "${TAG}" |awk -F'.' '{print $1}')
        minor=$(echo "${TAG}" |awk -F'.' '{print $2}')
        release=$(echo "${TAG}" |awk -F'.' '{print $3}')

        major=${major:-0}
        minor=${minor:-0}
        release=${release:-0}

        echo "${major},${major}.${minor},${major}.${minor}.${release},latest" > .tags
    fi
fi
if [ -n "${PLUGIN_TAGS:-}" ]; then
    DESTINATIONS=$(echo "${PLUGIN_TAGS}" | tr ',' '\n' | while read tag; do echo
    "--destination=${REGISTRY}/${PLUGIN_REPO}:${tag} "; done)
elif [ -f .tags ]; then
    DESTINATIONS=$(cat .tags| tr ',' '\n' | while read tag; do echo
    "--destination=${REGISTRY}/${PLUGIN_REPO}:${tag} "; done)
elif [ -n "${PLUGIN_REPO:-}" ]; then
    DESTINATIONS="--destination=${REGISTRY}/${PLUGIN_REPO}:latest"
else
    DESTINATIONS="--no-push"
fi

# mkdir -p /kaniko/.docker
# echo "{\"auths\":{\"$CI_REGISTRY\":{\"auth\":\"$(echo -n $CI_REGISTRY_USER:$CI_REGISTRY_PASSWORD | base64)\"}}}" > /kaniko/.docker/config.json

set -x
/kaniko/executor \
    --reproducible \
    ${CACHE} \
    ${CACHE_DIR} \
    ${CACHE_TTL} \
    --context ${CONTEXT} \
    --dockerfile ${DOCKERFILE} \
    ${BUILD_ARGS:-} \
    ${BUILD_ARGS_FROM_ENV:-} \
    ${PLUGIN_EXTRA_ARGS:-} \
    ${DESTINATIONS} \
