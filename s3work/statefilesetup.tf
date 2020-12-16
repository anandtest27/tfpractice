# Declare provider and profile

provider aws {
    region = "ap-south-1"
    shared_credentials_file = "/root/.aws/credentials"
    profile = "default"

}

# create a s3 bucket for shared storage for terraform state files

resource "aws_s3_bucket" "bucketfortf" {
  bucket = "tf-main-storage"
  lifecycle {
    prevent_destroy = true
  }
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  
}

# Create dynamo db table for locking the terraform

resource "aws_dynamodb_table" "lockfortf" {
  name = "tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  
}
