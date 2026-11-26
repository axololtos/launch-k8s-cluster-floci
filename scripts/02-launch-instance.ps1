# Step 2: launch nextwork-eks-instance, then give it an AdministratorAccess role.
. "$PSScriptRoot\env.ps1"

$ami = Invoke-Aws ec2 describe-images --filters 'Name=name,Values=al2023-ami-2023*x86_64' --query 'Images[0].ImageId' --output text
$sg  = Invoke-Aws ec2 describe-security-groups --filters 'Name=group-name,Values=default' --query 'SecurityGroups[0].GroupId' --output text

# Same as the project: SSH open to the world on the default group (fine for a local fake).
Invoke-AwsQuiet ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 22 --cidr 0.0.0.0/0 | Out-Null

$id = Invoke-Aws ec2 run-instances --image-id $ami --instance-type t3.micro --security-group-ids $sg `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$InstanceName}]" `
    --query 'Instances[0].InstanceId' --output text
"Launched $id"

# IAM role the instance will use (project step 3).
$trustFile = New-TemporaryFile
Set-Content $trustFile '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
Invoke-Aws iam create-role --role-name $RoleName --assume-role-policy-document "file://$trustFile" `
    --description "Grants an EC2 instance AdministratorAccess to my AWS account. Created during NextWork's Kubernetes project." | Out-Null
Remove-Item $trustFile
Invoke-Aws iam attach-role-policy --role-name $RoleName --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
Invoke-Aws iam create-instance-profile --instance-profile-name $RoleName | Out-Null
Invoke-Aws iam add-role-to-instance-profile --instance-profile-name $RoleName --role-name $RoleName
Invoke-Aws ec2 associate-iam-instance-profile --instance-id $id --iam-instance-profile Name=$RoleName | Out-Null

Invoke-Aws ec2 describe-instances --instance-ids $id `
    --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,IamInstanceProfile.Arn]' --output table
