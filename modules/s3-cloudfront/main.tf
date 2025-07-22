resource "aws_s3_bucket" "vue_site" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "vue_site" {
  bucket = aws_s3_bucket.vue_site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "vue_site" {
  bucket = aws_s3_bucket.vue_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "vue_site" {
  bucket = aws_s3_bucket.vue_site.id
  depends_on = [aws_s3_bucket_public_access_block.vue_site]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.vue_site.arn}/*"
      },
    ]
  })
}


resource "aws_cloudfront_distribution" "cdn" {
  # S3 Origin for frontend
  origin {
    domain_name = aws_s3_bucket_website_configuration.vue_site.website_endpoint
    origin_id   = "vueS3Origin"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API Origin for backend
  origin {
    domain_name = var.api_domain_name  # We'll pass this as a variable
    origin_id   = "apiOrigin"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "index.html"

  # Default behavior for frontend
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "vueS3Origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # API behavior for backend
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "apiOrigin"

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
