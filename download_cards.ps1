# Script tai du 78 la bai Rider-Waite chinh chu tu metabismuth/tarot-json
$baseUrl = "https://raw.githubusercontent.com/metabismuth/tarot-json/master/cards"
$targetDir = "c:\Users\thewo\Downloads\TarotDesk\tarot_desk_flutter\assets\images"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

$cards = @()

# 22 Major Arcana (m00.jpg -> m21.jpg)
for ($i = 0; $i -le 21; $i++) {
    $cards += ("m{0:D2}.jpg" -f $i)
}

# 56 Minor Arcana (w01-w14, c01-c14, s01-s14, p01-p14)
$suits = @('w', 'c', 's', 'p')
foreach ($suit in $suits) {
    for ($i = 1; $i -le 14; $i++) {
        $cards += ("{0}{1:D2}.jpg" -f $suit, $i)
    }
}

Write-Host ("Dang tai {0} la bai Rider-Waite chinh chu..." -f $cards.Count) -ForegroundColor Cyan

$successCount = 0
foreach ($cardFile in $cards) {
    $filePath = Join-Path $targetDir $cardFile
    $url = "$baseUrl/$cardFile"
    
    if (-not (Test-Path $filePath)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $filePath -ErrorAction Stop
            $successCount++
            Write-Host ("+ Da tai: {0}" -f $cardFile) -ForegroundColor Green
        } catch {
            Write-Host ("- Loi tai {0}: {1}" -f $cardFile, $_) -ForegroundColor Red
        }
    } else {
        $successCount++
    }
}

Write-Host ("DA TAI THANH CONG {0}/{1} LA BAI RIDER-WAITE CHINH CHU!" -f $successCount, $cards.Count) -ForegroundColor Green
