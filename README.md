# Core Cloud Ingress Terraform

This repository contains Terraform modules for ingress components under modules/ingress.

## Terraform Tests

Terraform test files are stored in each module under a tests directory.

Current test files:

- modules/ingress/acm/tests/acm.tftest.hcl
- modules/ingress/alb/tests/alb.tftest.hcl
- modules/ingress/custom-alb/tests/custom-alb.tftest.hcl
- modules/ingress/dns-isolated/route53-public-zone/tests/route53-public-zone.tftest.hcl
- modules/ingress/nlb/tests/nlb.tftest.hcl
- modules/ingress/nlb-ips/tests/nlb-ips.tftest.hcl
- modules/ingress/nlb-isolated/tests/nlb-isolated.tftest.hcl
- modules/ingress/private-subnets/tests/private-subnets.tftest.hcl
- modules/ingress/route53-private-zone/tests/route53-private-zone.tftest.hcl
- modules/ingress/route53-public-zone/tests/route53-public-zone.tftest.hcl

### Test Design

- Tests are plan-only and run with Terraform mock providers.
- This allows local execution without real AWS credentials for these module tests.
- Some modules include multiple run blocks to cover both disabled and enabled feature paths.

## Run Tests Locally

### Prerequisites

- Terraform 1.7.0 or newer (mock providers are required by the test suite).

Check your Terraform version:

```bash
terraform version
```

### Run tests for one module

Example for the ALB module:

```bash
cd modules/ingress/alb
terraform init
terraform test -no-color
```

### Run tests for all ingress modules

From repository root:

```bash
while IFS= read -r module_dir; do
	echo "===== ${module_dir} ====="
	(
		cd "${module_dir}" || exit 1
		terraform init -no-color >/dev/null
		terraform test -no-color
	)
done < <(find modules/ingress -type d -name tests | sed 's#/tests##' | sort)
```

### Optional: concise pass or fail summary

```bash
while IFS= read -r module_dir; do
	(
		cd "${module_dir}" || exit 1
		terraform test -no-color >/tmp/tf-test-output.txt 2>&1
	)

	if [ $? -eq 0 ]; then
		echo "PASS ${module_dir}"
	else
		echo "FAIL ${module_dir}"
		sed -n '1,80p' /tmp/tf-test-output.txt
	fi
done < <(find modules/ingress -type d -name tests | sed 's#/tests##' | sort)
```
