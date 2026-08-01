package main

deny contains msg if {
	input.kind == "Deployment"
	not input.spec.template.spec.securityContext.runAsNonRoot
	msg := "Pod must set spec.template.spec.securityContext.runAsNonRoot to true"
}

deny contains msg if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not container.securityContext.readOnlyRootFilesystem
	msg := sprintf("Container '%s' must set readOnlyRootFilesystem to true", [container.name])
}

deny contains msg if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	container.securityContext.allowPrivilegeEscalation != false
	msg := sprintf("Container '%s' must set allowPrivilegeEscalation to false", [container.name])
}

deny contains msg if {
	input.kind == "Deployment"
	container := input.spec.template.spec.containers[_]
	not capability_all_dropped(container)
	msg := sprintf("Container '%s' must drop ALL capabilities", [container.name])
}

capability_all_dropped(container) if {
	container.securityContext.capabilities.drop[_] == "ALL"
}
