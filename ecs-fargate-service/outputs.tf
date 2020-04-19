output "url" {
  value = "https://${var.public_lb_dns_name}.${trim(var.public_lb_dns_zone, ".")}"
}

