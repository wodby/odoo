# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := odoo
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_18.0-20261102 := sha256:079fd036571bb426b077eb1232d7dd8b6e5c9b7ad49a7363f1b722bd0f5dcd05
BASE_IMAGE_DIGEST_19.0-20261102 := sha256:4f3c722d934ed64300bc7df7448c24e952501424aacfa103407b702adf8573ce
BASE_IMAGE_DIGEST_20.0-20261102 := sha256:68a96ddcbb3e3cc3f6ce1462defd20ca62baef11d599fb70dedc11505e979015

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
