function Get-GlicLicenses {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string[]]$SkuIds,
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx        = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $skuIdsFlag = if ($SkuIds) { $SkuIds -join ',' } else { $null }
    $skus       = Get-GlicSkuCatalog -SkuIds $skuIdsFlag

    # Fetch all users into a lookup dictionary for enrichment
    $userMap = @{}
    Invoke-GlicPagedRequest `
        -Uri     'https://admin.googleapis.com/admin/directory/v1/users' `
        -Headers $ctx.Headers `
        -Query   @{ customer = $ctx.CustomerId; maxResults = 500; projection = 'full' } `
        -ItemsProperty 'users' |
    ForEach-Object { if ($_.primaryEmail) { $userMap[$_.primaryEmail] = $_ } }

    foreach ($sku in $skus) {
        $uri   = "https://licensing.googleapis.com/apps/licensing/v1/product/$($sku.ProductId)/sku/$($sku.SkuId)/users"
        $query = @{ customerId = $ctx.CustomerId; maxResults = 1000 }

        try {
            $assignments = @(Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'items')
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -in @(400, 403, 404)) { continue }
            Write-Warning "Skipping $($sku.SkuId): $($_.Exception.Message)"
            continue
        }

        if ($assignments.Count -eq 0) {
            Write-Warning "SKU '$($sku.SkuName)' ($($sku.SkuId)) returned no individual assignments - skipped."
            continue
        }

        foreach ($a in $assignments) {
            $user      = if ($a.userId) { $userMap[$a.userId] } else { $null }
            $lastLogin = if ($user -and $user.lastLoginTime) { [DateTimeOffset]::Parse($user.lastLoginTime) } else { $null }
            [PSCustomObject]@{
                ReportDate       = $reportDate
                CustomerId       = $ctx.CustomerId
                UserEmail        = if ($a.userId)                    { $a.userId }             else { '' }
                FullName         = if ($user -and $user.name)        { $user.name.fullName }   else { '' }
                GivenName        = if ($user -and $user.name)        { $user.name.givenName }  else { '' }
                FamilyName       = if ($user -and $user.name)        { $user.name.familyName } else { '' }
                OrgUnit          = if ($user -and $user.orgUnitPath) { $user.orgUnitPath }     else { '' }
                IsAdmin          = if ($user) { $user.isAdmin }   else { $null }
                Suspended        = if ($user) { $user.suspended } else { $null }
                LastLoginTime    = $lastLogin
                ProductId        = $sku.ProductId
                ProductName      = $sku.ProductName
                SkuId            = $sku.SkuId
                SkuName          = $sku.SkuName
                AssignmentStatus = 'ACTIVE'
            }
        }
    }
}
