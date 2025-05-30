# 사용자 홈 디렉터리 경로 가져오기
$userProfile = [System.Environment]::GetFolderPath('UserProfile')

# known_hosts 파일 경로
$knownHostsPath = Join-Path -Path $userProfile -ChildPath '.ssh\known_hosts'

# known_hosts 파일이 존재하면
if (Test-Path $knownHostsPath) {
    # 파일 내용을 비우기
    Clear-Content -Path $knownHostsPath
    Write-Host "known_hosts cleared"
} else {
    Write-Host "known_hosts not exists"
}