# Step 7 (secret mission): delete a node and watch it come back.
# Floci refuses TerminateInstances on EKS nodes and has no Auto Scaling replacement,
# so this deletes the Kubernetes node object, then restarts the k3s container (the one node)
# so the kubelet registers a fresh node, which is what a replacement instance would do.
. "$PSScriptRoot\env.ps1"

Invoke-Aws eks update-kubeconfig --name $Cluster --kubeconfig $Kubeconfig | Out-Null
$env:KUBECONFIG = $Kubeconfig

# Floci rejects the shared test/test pair for cluster auth, so sign in as the IAM user from step 6.
Remove-AccessKeys
$key = Invoke-Aws iam create-access-key --user-name nextwork-admin | ConvertFrom-Json
$env:AWS_ACCESS_KEY_ID     = $key.AccessKey.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $key.AccessKey.SecretAccessKey

# kubectl prints "No resources found" and API-start errors on stderr; show them as plain text.
function Get-Nodes {
    $ErrorActionPreference = 'Continue'
    kubectl get nodes @args 2>&1 | ForEach-Object { "$_" }
}

function Wait-Node {
    for ($i = 0; $i -lt 60; $i++) {
        if ((Get-Nodes --no-headers) -match ' Ready') { return }
        Start-Sleep 5
    }
    throw 'Node never became Ready'
}

Wait-Node
"Before:"
Get-Nodes
$node = Get-Nodes -o jsonpath='{.items[0].metadata.name}'
"`nDeleting node $node"
kubectl delete node $node
"`nRight after delete:"
Get-Nodes
"`nRestarting the node..."
docker restart "floci-aws-eks-$Cluster" | Out-Null
Wait-Node
"`nReplacement node:"
Get-Nodes
