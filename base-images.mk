# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := odoo
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_18.0-20261112 := sha256:d0b20aa4ec8a4d97ca096ada36275d77963d571c1cb1cceca69faf6098326c83
BASE_IMAGE_DIGEST_19.0-20261112 := sha256:49c9d2a9935f07f15e2404ce8649a84c4f0d4e70a880f7209ad27a19ab415f77
BASE_IMAGE_DIGEST_20.0-20261112 := sha256:8bcae4c1f895683ee851e19dd3e7d999e81e770defe9015bc9dad8bbf10f2b0d

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
