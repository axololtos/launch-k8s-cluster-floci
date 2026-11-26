# Step 6: map an IAM principal to Kubernetes with an EKS access entry.
. "$PSScriptRoot\env.ps1"

Invoke-AwsQuiet iam create-user --user-name nextwork-admin | Out-Null
$arn = Invoke-Aws iam get-user --user-name nextwork-admin --query 'User.Arn' --output text

Invoke-AwsQuiet eks create-access-entry --cluster-name $Cluster --principal-arn $arn --type STANDARD | Out-Null

# Floci 2.3.0 answers "Unknown operation" for every access-policy call on a principal ARN that
# contains a slash (all users and roles), so the policy cannot be attached here.
try {
    Invoke-Aws eks associate-access-policy --cluster-name $Cluster --principal-arn $arn `
        --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy `
        --access-scope type=cluster | Out-Null
    "Associated AmazonEKSClusterAdminPolicy"
} catch {
    "NOTE: AmazonEKSClusterAdminPolicy was not attached (Floci 2.3.0 limitation, see README)."
}

"`nAccess entries:"
Invoke-Aws eks list-access-entries --cluster-name $Cluster --output table
"`nEntry:"
Invoke-Aws eks describe-access-entry --cluster-name $Cluster --principal-arn $arn `
    --query 'accessEntry.[principalArn,type]' --output table
