$projectId = "1360125"
$token = "1eba443c-14c8-49ad-a0a6-fb9bdf47d9fd"
$payload = '{ "ref": "refs/heads/main", "after": "0000000000000000000000000000000000000000" }'
Invoke-RestMethod -Method Post -Uri "https://www.curseforge.com/api/projects/$projectId/package?token=$token" -Body $payload -ContentType "application/json"