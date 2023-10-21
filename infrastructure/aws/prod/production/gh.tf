#  PAT with (for private): repo | Full control of private repositories
#  ENV: set TF_VAR_ghtf=<personal_access_token>
#     Personal Access Token (PAT)
#      https://docs.github.com/en/enterprise-server@3.4/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

variable "ghtf" {} # read PAT from the environment (use 'set TF_VAR_ghtf=<personal_access_token>')

# set  <DEPLOYMENT>_<INTERFACE>_CLOUDFRONT = aws_cloudfront_distribution.webapp_mainline.id
resource "github_actions_secret" "set_cloudfront_secret" {
  repository = "frame" # private requires PAT with all repo permissions

  secret_name     = "PRODUCTION_MAINLINE_CLOUDFRONT"
  plaintext_value = module.primary_base.cloudfront_distribution
}

# set  <DEPLOYMENT>_<INTERFACE>_CLOUDFRONT = aws_cloudfront_distribution.quick_webapp_mainline.id
resource "github_actions_secret" "set_quick_cloudfront_secret" {
  repository = "frame" # private requires PAT with all repo permissions

  secret_name     = "PRODUCTION_QUICK_CLOUDFRONT"
  plaintext_value = module.primary_base.quick_cloudfront_distribution
}
