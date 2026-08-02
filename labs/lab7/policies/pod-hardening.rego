package main

# Rule 1:
# The pod-level securityContext.runAsNonRoot field must be set to true.
deny contains msg if {
    input.kind == "Deployment"

    pod_spec := input.spec.template.spec
    pod_security_context := object.get(
        pod_spec,
        "securityContext",
        {}
    )
    run_as_non_root := object.get(
        pod_security_context,
        "runAsNonRoot",
        false
    )

    run_as_non_root != true

    msg := "Pod must set spec.securityContext.runAsNonRoot to true"
}

# Rule 2:
# Every container must use a read-only root filesystem.
deny contains msg if {
    input.kind == "Deployment"

    container := input.spec.template.spec.containers[_]
    container_security_context := object.get(
        container,
        "securityContext",
        {}
    )
    read_only_root_filesystem := object.get(
        container_security_context,
        "readOnlyRootFilesystem",
        false
    )

    read_only_root_filesystem != true

    msg := sprintf(
        "Container %q must set securityContext.readOnlyRootFilesystem to true",
        [container.name]
    )
}

# Rule 3:
# Every container must disable privilege escalation.
deny contains msg if {
    input.kind == "Deployment"

    container := input.spec.template.spec.containers[_]
    container_security_context := object.get(
        container,
        "securityContext",
        {}
    )
    allow_privilege_escalation := object.get(
        container_security_context,
        "allowPrivilegeEscalation",
        true
    )

    allow_privilege_escalation != false

    msg := sprintf(
        "Container %q must set securityContext.allowPrivilegeEscalation to false",
        [container.name]
    )
}

# Rule 4:
# Every container must drop all Linux capabilities.
deny contains msg if {
    input.kind == "Deployment"

    container := input.spec.template.spec.containers[_]
    container_security_context := object.get(
        container,
        "securityContext",
        {}
    )
    capabilities := object.get(
        container_security_context,
        "capabilities",
        {}
    )
    dropped_capabilities := object.get(
        capabilities,
        "drop",
        []
    )

    not "ALL" in dropped_capabilities

    msg := sprintf(
        "Container %q must include ALL in securityContext.capabilities.drop",
        [container.name]
    )
}
