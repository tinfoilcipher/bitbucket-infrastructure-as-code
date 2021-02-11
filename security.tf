#--Provision VPC Security Groups
resource "aws_security_group" "tinfoil_bastion" {
    vpc_id      = aws_vpc.tinfoil_vpc.id
    name        = "BastionSecurityGroup-${var.environment_name}"
    description = "SSH and Egress to Bastion host"
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.wan_edge_ip]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name        = "BastionSecurityGroup-${var.environment_name}"
        Environment = var.environment_name
    }
}

resource "aws_security_group" "tinfoil_private" {
    vpc_id      = aws_vpc.tinfoil_vpc.id
    name        = "PrivateSecurityGroup-${var.environment_name}"
    description = "SSH and Egress for Private Subnet"
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [var.bastion_cidr]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name        = "PrivateSecurityGroup-${var.environment_name}"
        Environment = var.environment_name
    }
}

#--Provision NACLs
resource "aws_network_acl" "tinfoil_bastion" {
    vpc_id = aws_vpc.tinfoil_vpc.id
    subnet_ids  = [aws_subnet.tinfoil_bastion.id]
    ingress {
        protocol   = "tcp"
        rule_no    = 100
        action     = "allow"
        cidr_block = var.wan_edge_ip
        from_port  = 22
        to_port    = 22
    }
    ingress {
        protocol   = "-1"
        rule_no    = 199
        action     = "allow"
        cidr_block = var.private_cidr
        from_port  = 0
        to_port    = 0
    }
    egress {
        protocol   = -1 #--All
        rule_no    = 1000
        action     = "allow"
        cidr_block = "0.0.0.0/0"
        from_port  = 0
        to_port    = 0
    }   
    tags = {
        Name        = "BastionNACL-${var.environment_name}"
        Environment = var.environment_name
    }
}

#--Provision S3 Policies
resource "aws_s3_bucket_policy" "tinfoil" {
        bucket = aws_s3_bucket.tinfoil.id
        policy = <<POLICY
{
    "Id": "SourceIP",
    "Version": "2012-10-17",
    "Statement": 
    [
        {
            "Sid": "SourceIP",
            "Action": "s3:*",
            "Effect": "Deny",
            "Resource": [
                "arn:aws:s3:::tinfoilcipherstorage-${var.environment_name}",
                "arn:aws:s3:::tinfoilcipherstorage-${var.environment_name}/*"
            ],
            "Condition": {
                "NotIpAddress": {
                    "aws:SourceIp": [
                        "${var.wan_edge_ip}"
                    ]
                }
            },
        "Principal": "*"
        }
    ]
}
POLICY
        depends_on = [
            aws_s3_bucket_public_access_block.tinfoil
        ]
}