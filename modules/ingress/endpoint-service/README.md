

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.99.1 |

## Resources

| Name | Type |
|------|------|
| [aws_vpc_endpoint_service.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service) | resource |
| [aws_vpc_endpoint_service_allowed_principal.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service_allowed_principal) | resource |
| [aws_vpc_endpoint_service_private_dns_verification.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_service_private_dns_verification) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acceptance_required"></a> [acceptance\_required](#input\_acceptance\_required) | Whether or not VPC endpoint connection requests to the service must be accepted by the service owner - true or false. | `bool` | `true` | no |
| <a name="input_allowed_principals"></a> [allowed\_principals](#input\_allowed\_principals) | The ARNs of one or more principals allowed to discover the endpoint service. | `set(string)` | `[]` | no |
| <a name="input_network_load_balancer_arns"></a> [network\_load\_balancer\_arns](#input\_network\_load\_balancer\_arns) | Amazon Resource Names (ARNs) of one or more Network Load Balancers for the endpoint service. | `set(string)` | n/a | yes |
| <a name="input_principal_arns"></a> [principal\_arns](#input\_principal\_arns) | The ARN of the principals allowed to discover the VPC endpoint service. | `set(string)` | `[]` | no |
| <a name="input_private_dns_name"></a> [private\_dns\_name](#input\_private\_dns\_name) | The private DNS name for the service. | `string` | `null` | no |
| <a name="input_private_dns_verification"></a> [private\_dns\_verification](#input\_private\_dns\_verification) | Begins the verification process. The service provider should add a record to the DNS server before setting this to true. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_default"></a> [default](#output\_default) | A map containing details about the endpoint service. |
