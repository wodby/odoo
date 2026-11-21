# Base image inputs shared by local builds and CI. Updated by wodby/images.
# Each digest identifies the complete multi-platform image index.
BASE_IMAGE_REPOSITORY := odoo
BASE_IMAGE_VERSION_SUFFIX :=

BASE_IMAGE_DIGEST_18.0-20261112 := sha256:0bd79cf07f59105c5697667c2241b86447e99c6adb036200df0e4e295785bdf3
BASE_IMAGE_DIGEST_19.0-20261112 := sha256:03a47921f9eef2c225ded1167fe7828465d2b3177883f30d173bb1c3c792949b
BASE_IMAGE_DIGEST_20.0-20261112 := sha256:c7352c766b245b3c0e5c7b7a57e7660dde3265872be9566870d44bdb974f44cf

# Fail before building when a version has no reviewed pin.
BASE_IMAGE = $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG)@$(or $(BASE_IMAGE_DIGEST_$(BASE_IMAGE_TAG)),$(error No base image digest for $(BASE_IMAGE_REPOSITORY):$(BASE_IMAGE_TAG); update base-images.mk))
