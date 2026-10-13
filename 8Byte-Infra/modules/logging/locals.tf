locals {
  system_log_files = {
    messages   = "/var/log/messages"
    secure     = "/var/log/secure"
    cloud_init = "/var/log/cloud-init-output.log"
  }
  docker_logging_config = jsonencode({
    "log-driver" = "awslogs"
    "log-opts" = {
      "awslogs-region"       = var.aws_region
      "awslogs-group"        = aws_cloudwatch_log_group.application.name
      "awslogs-create-group" = "false"
      "tag"                  = "{{.Name}}/{{.FullID}}"
      "mode"                 = "non-blocking"
      "max-buffer-size"      = "4m"
      "cache-disabled"       = "false"
      "cache-max-size"       = "10m"
      "cache-max-file"       = "3"
    }
  })
}

locals {
  host_metric_namespace = "${var.project_name}/Host"
  cloudwatch_agent_config = jsonencode({
    agent = { metrics_collection_interval = 60, region = var.aws_region }
    logs = {
      force_flush_interval = 5
      logs_collected = {
        files = {
          collect_list = [for name, path in local.system_log_files : {
            file_path       = path
            log_group_name  = aws_cloudwatch_log_group.system.name
            log_stream_name = "{instance_id}/${name}"
          }]
        }
      }
    }
    metrics = {
      namespace              = local.host_metric_namespace
      append_dimensions      = { InstanceId = "$${aws:InstanceId}" }
      aggregation_dimensions = [["InstanceId"]]
      metrics_collected = {
        mem = {
          measurement           = ["used_percent"]
          drop_original_metrics = ["mem_used_percent"]
        }
        disk = {
          resources             = ["/"]
          measurement           = ["used_percent"]
          drop_device           = true
          drop_original_metrics = ["disk_used_percent"]
        }
      }
    }
  })
}
