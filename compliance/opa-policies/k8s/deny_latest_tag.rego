package k8s.deny_latest_tag

import future.keywords.if

deny[msg] if {
    container := input.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%v' must not use ':latest' image tag — pin to an immutable digest or version tag", [container.name])
}

deny[msg] if {
    container := input.spec.containers[_]
    not contains(container.image, ":")
    msg := sprintf("Container '%v' image '%v' has no tag — must specify an explicit tag or digest", [container.name, container.image])
}
