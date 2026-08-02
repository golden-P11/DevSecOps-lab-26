package main

import rego.v1

# Rule 1:
# runAsNonRoot must be set to true.
#
# It can be configured at:
# - Pod level: spec.template.spec.securityContext.runAsNonRoot
# - Container level: container.securityContext.runAsNonRoot
#
# A container is denied only when runAsNonRoot is not true
# at both the Pod level and the container level.
deny contains msg if {
    container := input.spec.template.spec.containers[_]

    not input.spec.template.spec.securityContext.runAsNonRoot == true
    not container.securityContext.runAsNonRoot == true

    msg := sprintf(
        "Container %q must set runAsNonRoot=true at pod or container level",
        [container.name],
    )
}

# Rule 2:
# Every container must disable privilege escalation.
deny contains msg if {
    container := input.spec.template.spec.containers[_]

    not container.securityContext.allowPrivilegeEscalation == false

    msg := sprintf(
        "Container %q must set securityContext.allowPrivilegeEscalation=false",
        [container.name],
    )
}

# Rule 3:
# Every container must drop all Linux capabilities.
deny contains msg if {
    container := input.spec.template.spec.containers[_]

    not "ALL" in container.securityContext.capabilities.drop

    msg := sprintf(
        "Container %q must include ALL in securityContext.capabilities.drop",
        [container.name],
    )
}

# Rule 4 - Optional:
# Every container must define a memory limit.
deny contains msg if {
    container := input.spec.template.spec.containers[_]

    not container.resources.limits.memory

    msg := sprintf(
        "Container %q must set resources.limits.memory",
        [container.name],
    )
}

# Rule 5 - Optional:
# Every container image must be pinned using a SHA-256 digest.
#
# Valid:
# nginx@sha256:abc123...
#
# Invalid:
# nginx:latest
# nginx:1.27
deny contains msg if {
    container := input.spec.template.spec.containers[_]

    not contains(container.image, "@sha256:")

    msg := sprintf(
        "Container %q image %q must use an immutable sha256 digest",
        [container.name, container.image],
    )
}
