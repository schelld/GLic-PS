function Invoke-GlicPagedRequest {
    [CmdletBinding()]
    param(
        [string]$Uri,
        [hashtable]$Headers,
        [hashtable]$Query         = @{},
        [string]$ItemsProperty,
        [string]$NextTokenProp    = 'nextPageToken'
    )

    $pageToken = $null
    do {
        $q = @{} + $Query
        if ($pageToken) { $q['pageToken'] = $pageToken }

        $qs = ($q.GetEnumerator() | Sort-Object Key | ForEach-Object {
            "$([Uri]::EscapeDataString($_.Key))=$([Uri]::EscapeDataString([string]$_.Value))"
        }) -join '&'

        $fullUri  = if ($qs) { "${Uri}?${qs}" } else { $Uri }
        $response = Invoke-RestMethod -Uri $fullUri -Headers $Headers -Method Get -ErrorAction Stop

        if ($ItemsProperty -and $response.$ItemsProperty) {
            $response.$ItemsProperty
        }

        $pageToken = $response.$NextTokenProp
    } while ($pageToken)
}
