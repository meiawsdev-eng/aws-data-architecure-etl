# EMR-managed security groups: created empty; EMR adds the node-to-node rules it needs.
# No inbound rule from the internet at all — we reach the cluster via Session Manager.

resource "aws_security_group" "primary" {
  name                   = "${local.prefix}-primary"
  description            = "EMR primary node; EMR adds the rules it needs"
  vpc_id                 = local.vpc_id
  revoke_rules_on_delete = true # EMR-added rules reference each other; revoke them so destroy works
  tags                   = merge(local.emr_tag, { Name = "${local.prefix}-primary" })
}

resource "aws_security_group" "core" {
  name                   = "${local.prefix}-core"
  description            = "EMR core nodes; EMR adds the rules it needs"
  vpc_id                 = local.vpc_id
  revoke_rules_on_delete = true
  tags                   = merge(local.emr_tag, { Name = "${local.prefix}-core" })
}

# Outbound only: nodes must reach AWS APIs (EMR, SSM, Glue, KMS) and S3.
resource "aws_vpc_security_group_egress_rule" "primary_all" {
  security_group_id = aws_security_group.primary.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "core_all" {
  security_group_id = aws_security_group.core.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
