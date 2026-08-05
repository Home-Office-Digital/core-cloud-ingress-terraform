output "default" {
  description = "A map containing details about the endpoint service."
  value = {
    arn          = aws_vpc_endpoint_service.default.arn
    service_name = aws_vpc_endpoint_service.default.service_name
  }
}
