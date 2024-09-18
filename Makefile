TARGET_ENV := dev
TF_INIT_VARS := terraform init -backend-config=envs/${TARGET_ENV}/backend.tfvars
TF_PLAN_VARS := terraform plan -var-file=envs/${TARGET_ENV}/variable.tfvars
TF_APPLY_VARS := terraform apply -var-file=envs/${TARGET_ENV}/variable.tfvars
TF_DESTROY_VARS := terraform destroy -var-file=envs/${TARGET_ENV}/variable.tfvars
TF_STATE_LIST := terraform state list
TF_STATE_SHOW := terraform state show

.PHONY: it
it:
	$(TF_INIT_VARS)

.PHONY: plan
plan:
	$(TF_PLAN_VARS)

.PHONY: apply
apply:
	$(TF_APPLY_VARS)

.PHONY: destroy
destroy:
	$(TF_DESTROY_VARS)

.PHONY: list
list:
	$(TF_STATE_LIST)

# ex) make show resource=aws_instance.example
.PHONY: show
show:
	$(TF_STATE_SHOW) $(resource)