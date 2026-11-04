# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := odoo
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_18.0-20261102 := sha256:f61d3e36eb699e63557bbcdf4d7bd659e51418c326009e6574565d87e1d9026d
BASE_IMAGE_DIGEST_19.0-20261102 := sha256:5e755c725b3c43cf0be16d579904e1418300db3a2c44952f928eaddbcb0cc16d
BASE_IMAGE_DIGEST_20.0-20261102 := sha256:a97a7665e2b9fd890e12785491a2c91d779f800bcbc30873dada1c8748b28f1c

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
