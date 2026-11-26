# Shared settings. Dot-source from every script: . "$PSScriptRoot\env.ps1"
$ErrorActionPreference = 'Stop'

# Dummy credentials: Floci accepts anything.
$env:AWS_ACCESS_KEY_ID     = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION    = 'us-east-1'
$env:AWS_ENDPOINT_URL      = 'http://localhost:4566'
$env:AWS_PAGER             = ''

$Root         = Split-Path $PSScriptRoot -Parent
$Templates    = Join-Path $Root 'templates'
$Cluster      = 'nextwork-eks-cluster'
$NodeGroup    = 'nextwork-nodegroup'
$InstanceName = 'nextwork-eks-instance'
$RoleName     = 'nextwork-eks-instance-role'
$ClusterStack = "eksctl-$Cluster-cluster"
$NodeStack    = "eksctl-$Cluster-nodegroup-$NodeGroup"
$Kubeconfig   = Join-Path $Root '.kubeconfig'

# Run aws and fail the script if it fails. Returns stdout as text.
function Invoke-Aws {
    $out = & aws @args
    if ($LASTEXITCODE -ne 0) { throw "aws $($args -join ' ') failed" }
    $out
}

# Best effort: ignore errors (already exists, already gone). Returns stdout, empty on failure.
function Invoke-AwsQuiet {
    $ErrorActionPreference = 'Continue'
    & aws @args 2>$null
}

# Delete every access key of the nextwork-admin user (2 is the per-user quota).
function Remove-AccessKeys {
    foreach ($k in (Invoke-AwsQuiet iam list-access-keys --user-name nextwork-admin --query 'AccessKeyMetadata[].AccessKeyId' --output text) -split '\s+') {
        if ($k) { Invoke-AwsQuiet iam delete-access-key --user-name nextwork-admin --access-key-id $k | Out-Null }
    }
}

# Wait until a stack reaches the given status.
function Wait-Stack($Name, $Status = 'CREATE_COMPLETE') {
    for ($i = 0; $i -lt 90; $i++) {
        $s = Invoke-Aws cloudformation describe-stacks --stack-name $Name --query 'Stacks[0].StackStatus' --output text
        if ($s -eq $Status) { return }
        if ($s -like '*FAILED*' -or $s -like 'ROLLBACK*') { throw "Stack $Name is $s" }
        Start-Sleep 5
    }
    throw "Timed out waiting for $Name"
}

# Wait until the k3s control plane answers and the cluster is ACTIVE.
function Wait-Cluster {
    for ($i = 0; $i -lt 60; $i++) {
        if ((Invoke-Aws eks describe-cluster --name $Cluster --query 'cluster.status' --output text) -eq 'ACTIVE') { return }
        Start-Sleep 5
    }
    throw "Cluster $Cluster never became ACTIVE"
}

# The instance id of the nextwork-eks-instance that is not terminated.
function Get-InstanceId {
    Invoke-Aws ec2 describe-instances --filters "Name=tag:Name,Values=$InstanceName" 'Name=instance-state-name,Values=pending,running' --query 'Reservations[].Instances[].InstanceId' --output text
}
