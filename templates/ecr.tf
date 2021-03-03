## SPDX-FileCopyrightText: Copyright 2019 Amazon.com, Inc. or its affiliates
##
### SPDX-License-Identifier: MIT-0

resource "aws_ecr_repository" "stepfunction_ecs_ecr_repo" {
  name = "${var.app_prefix}-repo"

  tags = {
    Name = "${var.app_prefix}-ecr-repo"
  }
}

resource "null_resource" "push_container" {
  depends_on = [aws_ecr_repository.stepfunction_ecs_ecr_repo]
  triggers = {
    dockerfile = "${sha256(file("../src/Dockerfile"))}"
    app_code   = "${sha256(file("../src/backup.py"))}"
  }


  provisioner "local-exec" {
    command = "./exec.sh ${aws_ecr_repository.stepfunction_ecs_ecr_repo.name} ${aws_ecr_repository.stepfunction_ecs_ecr_repo.repository_url}"
  }
}
