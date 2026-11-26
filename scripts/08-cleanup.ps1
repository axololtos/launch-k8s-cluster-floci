# Step 8: delete everything the project created.
. "$PSScriptRoot\env.ps1"

Invoke-AwsQuiet eks delete-nodegroup --cluster-name $Cluster --nodegroup-name $NodeGroup | Out-Null
Invoke-AwsQuiet eks delete-cluster --name $Cluster | Out-Null

foreach ($stack in $NodeStack, $ClusterStack) {   # node group first, as in the project
    Invoke-AwsQuiet cloudformation delete-stack --stack-name $stack | Out-Null
    for ($i = 0; $i -lt 60; $i++) {
        $s = Invoke-AwsQuiet cloudformation describe-stacks --stack-name $stack --query 'Stacks[0].StackStatus' --output text
        if (-not $s -or $s -eq 'DELETE_COMPLETE') { break }
        Start-Sleep 5
    }
    "$stack deleted"
}

$id = Get-InstanceId
if ($id) { Invoke-Aws ec2 terminate-instances --instance-ids $id | Out-Null; "Terminated $id" }

# Best effort: these may already be gone on a re-run.
Invoke-AwsQuiet iam remove-role-from-instance-profile --instance-profile-name $RoleName --role-name $RoleName | Out-Null
Invoke-AwsQuiet iam delete-instance-profile --instance-profile-name $RoleName | Out-Null
Invoke-AwsQuiet iam detach-role-policy --role-name $RoleName --policy-arn arn:aws:iam::aws:policy/AdministratorAccess | Out-Null
Invoke-AwsQuiet iam delete-role --role-name $RoleName | Out-Null
Remove-AccessKeys
Invoke-AwsQuiet iam delete-user --user-name nextwork-admin | Out-Null
Remove-Item $Kubeconfig -ErrorAction SilentlyContinue

"`nLeftovers (all should be empty):"
"clusters:       " + (Invoke-Aws eks list-clusters --query 'clusters' --output text)
"stacks:         " + (Invoke-Aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE --query 'StackSummaries[].StackName' --output text)
"elastic IPs:    " + (Invoke-Aws ec2 describe-addresses --query 'Addresses[].PublicIp' --output text)
"live instances: " + (Invoke-Aws ec2 describe-instances --filters 'Name=instance-state-name,Values=pending,running' --query 'Reservations[].Instances[].InstanceId' --output text)
