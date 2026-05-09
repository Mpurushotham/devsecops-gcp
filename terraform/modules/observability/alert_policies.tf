locals {
  notification_channels = concat(
    [google_monitoring_notification_channel.email.id],
    var.pagerduty_key != "" ? [google_monitoring_notification_channel.pagerduty[0].id] : []
  )
}

resource "google_monitoring_alert_policy" "iam_key_created" {
  project      = var.project_id
  display_name = "IAM Service Account Key Created"
  combiner     = "OR"

  conditions {
    display_name = "SA key creation audit log"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"
      EOT
    }
  }

  notification_channels = local.notification_channels
  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }
}

resource "google_monitoring_alert_policy" "org_policy_changed" {
  project      = var.project_id
  display_name = "Organization Policy Modified"
  combiner     = "OR"

  conditions {
    display_name = "Org policy change"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.serviceName="orgpolicy.googleapis.com"
      EOT
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "firewall_modified" {
  project      = var.project_id
  display_name = "Firewall Rule Modified"
  combiner     = "OR"

  conditions {
    display_name = "Firewall change"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.methodName=~"compute.firewalls.(insert|update|delete|patch)"
      EOT
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "gke_cluster_modified" {
  project      = var.project_id
  display_name = "GKE Cluster Configuration Changed"
  combiner     = "OR"

  conditions {
    display_name = "GKE cluster change"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.serviceName="container.googleapis.com"
        protoPayload.methodName=~"(Update|Delete|Create)Cluster"
      EOT
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "scc_critical_finding" {
  project      = var.project_id
  display_name = "SCC Critical Finding Published"
  combiner     = "OR"

  conditions {
    display_name = "Critical SCC finding"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/securitycenter.googleapis.com%2Ffinding"
        jsonPayload.finding.severity="CRITICAL"
      EOT
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "binary_auth_violation" {
  project      = var.project_id
  display_name = "Binary Authorization Policy Violation"
  combiner     = "OR"

  conditions {
    display_name = "Binary Auth deny"
    condition_matched_log {
      filter = <<-EOT
        resource.type="k8s_cluster"
        logName=~"binaryauthorization"
        jsonPayload.verdict="DENY"
      EOT
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "budget_exceeded" {
  project      = var.project_id
  display_name = "Budget Threshold Exceeded"
  combiner     = "OR"

  conditions {
    display_name = "Budget alert"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.serviceName="billingbudgets.googleapis.com"
      EOT
    }
  }

  notification_channels = local.notification_channels
}

resource "google_monitoring_alert_policy" "anomalous_iam_grant" {
  project      = var.project_id
  display_name = "Anomalous IAM Binding Added"
  combiner     = "OR"

  conditions {
    display_name = "Project IAM policy change"
    condition_matched_log {
      filter = <<-EOT
        logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity"
        protoPayload.methodName="SetIamPolicy"
        protoPayload.serviceData.policyDelta.bindingDeltas.action="ADD"
      EOT
    }
  }

  notification_channels = local.notification_channels
}
