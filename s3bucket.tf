# Declare provider and profile

provider aws {
    region = "ap-south-1"
    shared_credentials_file = "/root/.aws/credentials"
    profile = "s3profile"

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
  key = "aix_read.txt"
  source = "C:\\Users\\Lenovo\\Desktop\\AIX_read.txt"
  force_destroy = false
  
}
