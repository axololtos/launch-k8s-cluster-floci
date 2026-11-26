# Step 1: make sure the Floci emulator is up on port 4566.
. "$PSScriptRoot\env.ps1"

function Test-Floci { try { Invoke-RestMethod "$env:AWS_ENDPOINT_URL/_floci/health" -TimeoutSec 3 } catch { $null } }

$health = Test-Floci
if (-not $health) {
    # The Docker socket mount lets Floci start real containers for EC2 and EKS.
    docker run -d --name floci -p 4566:4566 -v /var/run/docker.sock:/var/run/docker.sock floci/floci:latest | Out-Null
    for ($i = 0; $i -lt 30 -and -not $health; $i++) { Start-Sleep 2; $health = Test-Floci }
}
if (-not $health) { throw 'Floci did not become healthy on port 4566' }

"Floci $($health.version) is up"
foreach ($s in 'ec2', 'eks', 'cloudformation', 'iam', 'autoscaling') {
    "{0,-15} {1}" -f $s, $health.services.$s
}
