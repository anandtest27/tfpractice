# Declare provider and profile

provider aws {
    region = "ap-south-1"
    shared_credentials_file = "/root/.aws/credentials"
    profile = "default"

}

# create s3 bucket and tagging

resource "aws_s3_bucket" "s3buc" {
  bucket = "ab-testbuc"
  acl = "private"

  tags = {
    Name = "My S3 user Bucket"
    Environment = "test"
  }
}

#  Add a file into the new bucket 

resource "aws_s3_bucket_object" "addfile" {
  bucket = aws_s3_bucket.s3buc.id
  key = "Loginmessages.txt"
  source = "/var/log/messages"
  force_destroy = false
  
}
