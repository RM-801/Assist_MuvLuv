param([Parameter(Mandatory=$true)][string]$ImagePath,
      [Parameter(Mandatory=$true)][string]$OutputPath, [string]$PreferredLanguage = 'ja*')
$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    $taskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    function Wait-WinRt($Operation, [Type]$ResultType) {
        $task = $taskMethod.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
        $task.Wait()
        return $task.Result
    }
    $file = Wait-WinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)) ([Windows.Storage.StorageFile])
    $stream = Wait-WinRt ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder = Wait-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap = Wait-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $language = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | Where-Object LanguageTag -Like $PreferredLanguage | Select-Object -First 1
    if ($null -eq $language) { $language = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | Select-Object -First 1 }
    if ($null -eq $language) { throw 'No Windows OCR language is installed.' }
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
    $result = Wait-WinRt ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $lines = @('OK')
    foreach ($line in $result.Lines) {
        $left = ($line.Words | ForEach-Object {$_.BoundingRect.X} | Measure-Object -Minimum).Minimum
        $top = ($line.Words | ForEach-Object {$_.BoundingRect.Y} | Measure-Object -Minimum).Minimum
        $right = ($line.Words | ForEach-Object {$_.BoundingRect.X + $_.BoundingRect.Width} | Measure-Object -Maximum).Maximum
        $bottom = ($line.Words | ForEach-Object {$_.BoundingRect.Y + $_.BoundingRect.Height} | Measure-Object -Maximum).Maximum
        $lines += ('{0}|{1}|{2}|{3}|{4}' -f [int]$left,[int]$top,[int]($right-$left),[int]($bottom-$top),($line.Text -replace '[\r\n|]',' '))
    }
    [IO.File]::WriteAllLines($OutputPath, $lines, [Text.UTF8Encoding]::new($true))
    $bitmap.Dispose()
    $stream.Dispose()
    exit 0
} catch {
    [IO.File]::WriteAllText($OutputPath, ('ERROR|' + $_.Exception.Message), [Text.UTF8Encoding]::new($true))
    exit 1
}
