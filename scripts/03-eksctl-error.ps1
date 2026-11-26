# Step 3: run eksctl on the instance. It is not installed, so this fails, as in the project.
. "$PSScriptRoot\env.ps1"

$id = Get-InstanceId
if (-not $id) { throw 'No running instance. Run 02-launch-instance.ps1 first.' }

# Floci runs each instance as a Docker container, so docker exec stands in for EC2 Instance Connect.
$container = docker ps --filter "name=$id" --format '{{.Names}}' | Select-Object -First 1
if (-not $container) { throw "No container found for $id" }

$cmd = "eksctl create cluster --name $Cluster --nodegroup-name $NodeGroup --node-type t3.micro --nodes 3 --nodes-min 1 --nodes-max 3 --version 1.33"
"[$InstanceName] `$ $cmd"
docker exec $container bash -c "$cmd 2>&1"   # the failure is the point; bash merges stderr so PowerShell does not abort
"exit code: $LASTEXITCODE (expected 127: command not found)"
exit 0
