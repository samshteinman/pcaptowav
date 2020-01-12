 param (
    [string]$tsharkExe = "C:\Program Files\Wireshark\tshark",
    [Parameter(Mandatory=$true)][string]$source,
    [Int32]$PCMSampleRate = 44100,
    [Int32]$PCMBitsPerSample = 16,
    [Int32]$PCMNChannels= 1
 )


function RemoveWiresharkSeparators()
{
    param( $path )

    $src = [System.IO.File]::ReadAllBytes($path)
    $dst = new-object byte[] $src.Length

    $i = 0
    $n = 0
    $skipped = 0
    do
    {
        if($src[$i] -eq 0x2C) # ,
        {
            $i +=1
            $skipped += 1
        }
        elseif($src[$i] -eq 0x0D -and $src[$i+1] -eq 0x0A  ) # ..
        {
          $i += 2;
          $skipped +=2;
        }
        else
        {
            [Array]::Copy($src, $i, $dst, $n, 2); 
            $i += 2;
            $n += 2;
        }       

        
    } while($i -lt ($src.Length))

    $dstwrite = new-object byte[] ($src.Length - $skipped)
    [Array]::Copy($dst, 0, $dstwrite, 0, $dstwrite.Length);
    [System.IO.File]::WriteAllBytes($path + ".withoutseparators", $dstwrite)

    return $path + ".withoutseparators"
}

function ConvertFromASCIIToRaw()
{
    param ($path)

    $m = [System.IO.File]::ReadAllBytes($path)

    $dst = new-object byte[] ($m.Length/2)
    $n = 0
    $i = 0
    while($i -lt $m.Length)
    {
        $c1 = [System.Text.ASCIIEncoding]::ASCII.GetString($m[$i],0,1)
        $c2 = [System.Text.ASCIIEncoding]::ASCII.GetString($m[$i+1],0,1)

        $b = [convert]::ToInt32($c1 + $c2,16)

        $dst[$n] = $b;

        $n += 1
        $i += 2
    }

    [System.IO.File]::WriteAllBytes($path + ".raw", $dst)
    return $path + ".raw";
}

$source = $source.Trim('"')

#Use TShark to extract data(currently extracts to ASCII instead of raw...)
$asciifile = ($source + ".ascii")
start-process -wait -ArgumentList  `"$tsharkExe`", `"$source`",`"$asciifile`" ".\tshark.bat"

Write "Removing wireshark separators from data"

$rawpath = RemoveWiresharkSeparators($asciifile);

Write "Converting from ascii to raw"

$actualDataPath = ConvertFromASCIIToRaw($rawpath);

Write "create wave format header"

add-type -Path ".\NAudio.dll"

$header = new-object NAudio.Wave.WaveFormat($PCMSampleRate,$PCMBitsPerSample,$PCMNChannels)

$actualData = [System.IO.File]::ReadAllBytes($actualDataPath)

$wavFilePath = $actualDataPath + ".wav"

$writer = new-object NAudio.Wave.WaveFileWriter($wavFilePath , $header)
$writer.WriteData($actualData, 0, $actualData.Length);

$writer.Dispose()