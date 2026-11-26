# Step 4: create the cluster as two CloudFormation stacks, the way eksctl does.
. "$PSScriptRoot\env.ps1"

Invoke-Aws cloudformation create-stack --stack-name $ClusterStack --template-body "file://$Templates/cluster.yaml" `
    --capabilities CAPABILITY_NAMED_IAM | Out-Null
Wait-Stack $ClusterStack
"$ClusterStack is CREATE_COMPLETE"

$out = Invoke-Aws cloudformation describe-stacks --stack-name $ClusterStack --query 'Stacks[0].Outputs' | ConvertFrom-Json
function Get-Output($Key) { ($out | Where-Object OutputKey -like $Key).OutputValue }
$subnets = Get-Output 'Subnet*'

# Created through the EKS API: Floci's CloudFormation ignores AccessConfig on create, and step 6 needs API mode.
Invoke-Aws eks create-cluster --name $Cluster --kubernetes-version 1.33 --role-arn (Get-Output 'ServiceRoleArn') `
    --resources-vpc-config "subnetIds=$($subnets -join ','),securityGroupIds=$(Get-Output 'SecurityGroupId')" `
    --access-config authenticationMode=API_AND_CONFIG_MAP | Out-Null

Invoke-Aws cloudformation create-stack --stack-name $NodeStack --template-body "file://$Templates/nodegroup.yaml" `
    --capabilities CAPABILITY_NAMED_IAM | Out-Null
Wait-Stack $NodeStack
"$NodeStack is CREATE_COMPLETE"

# The k3s control plane takes a moment to answer; the node group needs an ACTIVE cluster.
Wait-Cluster

# Also the EKS API: Floci's CloudFormation ignores ScalingConfig and InstanceTypes.
$nodeRole = Invoke-Aws cloudformation describe-stacks --stack-name $NodeStack --query 'Stacks[0].Outputs[0].OutputValue' --output text
Invoke-Aws eks create-nodegroup --cluster-name $Cluster --nodegroup-name $NodeGroup --node-role $nodeRole `
    --subnets $subnets --instance-types t3.micro --scaling-config 'minSize=1,maxSize=3,desiredSize=3' | Out-Null
Wait-Cluster   # Floci restarts the k3s container to apply the node group

Invoke-Aws eks describe-cluster --name $Cluster --query 'cluster.[name,status,version,endpoint]' --output table
Invoke-Aws eks describe-nodegroup --cluster-name $Cluster --nodegroup-name $NodeGroup --query 'nodegroup.[nodegroupName,status,instanceTypes[0],scalingConfig]' --output json
