output "node_instance_ip" {
  value       = aws_eip.node_ip.public_ip
  description = "Node instance's IPv4 address."
}
