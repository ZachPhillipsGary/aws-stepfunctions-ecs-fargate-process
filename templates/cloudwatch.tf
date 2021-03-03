## SPDX-FileCopyrightText: Copyright 2019 Amazon.com, Inc. or its affiliates
##
### SPDX-License-Identifier: MIT-0

resource "aws_cloudwatch_log_group" "stepfunction_ecs_container_cloudwatch_loggroup" {
  name = "${var.app_prefix}-cloudwatch-log-group"

  tags = {
    Name        = "${var.app_prefix}-cloudwatch-log-group"
    Environment = "${var.stage_name}"
  }
}

resource "aws_cloudwatch_log_stream" "stepfunction_ecs_container_cloudwatch_logstream" {
  name           = "${var.app_prefix}-cloudwatch-log-stream"
  log_group_name = "${aws_cloudwatch_log_group.stepfunction_ecs_container_cloudwatch_loggroup.name}"
}

resource "aws_cloudwatch_event_rule" "every_one_minute" {
  name                = "every-one-minute"
  description         = "Fires every one minutes"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "check_foo_every_one_minute" {
  rule      = "${aws_cloudwatch_event_rule.every_one_minute.name}"
  target_id = "lambda"
  arn       = "${aws_lambda_function.invoker.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.invoker.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every_one_minute.arn}"
}

# Begin ECR definition
resource "aws_ecr_repository" "lambda_ecr" {
  name = "${var.app_prefix}_lambda_ecr_${var.stage_name}"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "null_resource" "push_invoke_container" {
  depends_on = [aws_ecr_repository.lambda_ecr]
  triggers = {
    container_def_changes = "${sha256(file("${"../launcher/Dockerfile"}"))}",
    requirements_changes  = "${sha256(file("../launcher/requirements.txt"))}",
    lambda_code_changes   = "${sha256(file("../launcher/main.py"))}"
  }


  provisioner "local-exec" {
    command = "./exec.sh ${aws_ecr_repository.lambda_ecr.name} ${aws_ecr_repository.lambda_ecr.repository_url} launcher"
  }
}

output "ecr_url" {
  value = aws_ecr_repository.lambda_ecr.repository_url
}

resource "aws_lambda_function" "invoker" {
  depends_on    = [aws_ecr_repository.lambda_ecr, null_resource.push_invoke_container]
  function_name = "${var.app_prefix}_invoker_lambda_${var.stage_name}"
  image_uri     = "${aws_ecr_repository.lambda_ecr.repository_url}:latest" #"${aws_ecr_repository.lambda_ecr.repository_url}:latest"
  role          = aws_iam_role.invoker.arn
  package_type  = "Image"
  timeout       = 90
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      CLUSTER          = "${aws_ecs_cluster.stepfunction_ecs_cluster.id}",
      LAUNCH_TYPE      = "FARGATE",
      ASSIGN_PUBLIC_IP = "DISABLED",
      SUBNETS          = "${aws_subnet.stepfunction_ecs_private_subnet1.id}",
      SECURITY_GROUPS  = "${aws_security_group.stepfunction_ecs_security_group.id}",
      TASK_DEFINITION  = "${aws_ecs_task_definition.stepfunction_ecs_task_definition.arn}"
    }
  }
}

