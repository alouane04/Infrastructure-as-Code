output "app_url" {
    value = "http://${module.loadbalancer.alb_dns_name}"
    description = "URL to access the application"
}
