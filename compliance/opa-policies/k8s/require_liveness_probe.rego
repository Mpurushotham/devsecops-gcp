package k8s.require_liveness_probe

import future.keywords.if

deny[msg] if {
    container := input.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container '%v' must define a livenessProbe", [container.name])
}

deny[msg] if {
    container := input.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container '%v' must define a readinessProbe", [container.name])
}
