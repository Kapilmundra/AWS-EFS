provider "aws" {
  region     = "ap-south-1"
  profile    = "kapil"
}


#Security group
resource "aws_security_group" "security_permission" {
  name        = "security_permission"
  description = "Allow SSH and HTTP inbound traffic"

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security_permission"
  }
}


#Launch a ec2 instance
resource "aws_instance" "linuxworld" {
  depends_on = [ aws_security_group.security_permission ]
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  key_name      = "kapil1305"
  security_groups = [ "security_permission" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Kapil/Desktop/HybridCloud/kapil1305.pem")
    host     = aws_instance.linuxworld.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "LinuxWorld"
  }
}


#Launch one EFS
resource "aws_efs_file_system" "allow_nfs" {
  depends_on = [ aws_instance.linuxworld ]
  creation_token = "allow_nfs"
  tags = {
    Name = "allow_nfs"
  }
}

#Attach efs to ec2_instance
resource "aws_efs_mount_target" "alpha" {
  depends_on = [ aws_efs_file_system.allow_nfs ]
  file_system_id = aws_efs_file_system.allow_nfs.id
  subnet_id      = aws_instance.linuxworld.subnet_id
  security_groups = [ "${aws_security_group.security_permission.id}" ]
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_efs_file_system.allow_nfs,aws_efs_mount_target.alpha
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Kapil/Desktop/HybridCloud/kapil1305.pem")
    host     = aws_instance.linuxworld.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mount  ${aws_efs_file_system.allow_nfs.dns_name}:/  /var/www/html",
      "sudo echo ${aws_efs_file_system.allow_nfs.dns_name}:/ /var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Kapilmundra/AWS-EFS.git /var/www/html/"
    ]
  }
}


resource "aws_s3_bucket" "github-image-upload13" {
  depends_on = [ null_resource.nullremote3 ]
  bucket = "github-image-upload13"
  acl    = "public-read"

  tags = {
    Name        = "github-image-upload13"
  }



}


resource "aws_s3_bucket_object" "task2-bucket" {
  depends_on = [
    aws_s3_bucket.github-image-upload13,
  ]
  bucket = "github-image-upload13"
  key    = "terraform.png"
  source = "C:/Users/Kapil/Desktop/HybridCloud/terraform.png"
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.github-image-upload13.id
  policy = <<POLICY
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowPublicRead",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::github-image-upload13/*"
        }
    ]
}
POLICY
}


# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "prod_distribution1305" {
    depends_on = [ aws_s3_bucket_object.task2-bucket ]
    origin {
        domain_name = aws_s3_bucket.github-image-upload13.bucket_regional_domain_name
        origin_id = "S3-github-images-upload13" 

        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-github-images-upload13"

        # Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }



    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }

    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}












