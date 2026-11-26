# Step 5: the CloudFormation view of the cluster (events and resources of both stacks).
. "$PSScriptRoot\env.ps1"

Invoke-Aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE CREATE_IN_PROGRESS `
    --query 'StackSummaries[].[StackName,StackStatus]' --output table

foreach ($stack in $ClusterStack, $NodeStack) {
    "`n== $stack events (oldest first) =="
    Invoke-Aws cloudformation describe-stack-events --stack-name $stack `
        --query 'reverse(StackEvents)[].[LogicalResourceId,ResourceType,ResourceStatus]' --output table
}

"`n== $ClusterStack resources =="
Invoke-Aws cloudformation describe-stack-resources --stack-name $ClusterStack `
    --query 'StackResources[].[LogicalResourceId,ResourceType,ResourceStatus]' --output table
