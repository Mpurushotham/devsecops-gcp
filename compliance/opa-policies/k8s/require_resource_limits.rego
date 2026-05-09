package k8s.require_resource_limits

import future.keywords.if

deny[msg] if {
    container := input.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("Container '%v' must set resources.limits.cpu", [container.name])
}

deny[msg] if {
    container := input.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container '%v' must set resources.limits.memory", [container.name])
}
