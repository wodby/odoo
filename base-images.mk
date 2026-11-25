# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := odoo
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_18.0-20261124 := sha256:364b17dfcf0019c9e5c7e1754a56b36c748f2907b38bc2209ce0d3d88e371c35
BASE_IMAGE_DIGEST_19.0-20261123 := sha256:c30b26d599d06c2fe9ce5c215725f034ad7636326b4f9ce2469eabb5e59ea1a3
BASE_IMAGE_DIGEST_20.0-20261123 := sha256:6709a38456a588273462c83400a0b6dbe09038deefc05846a8d3d25231dbb82e

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
