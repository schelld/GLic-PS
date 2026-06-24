function Get-GlicUsers {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$OrgUnit,
        [ValidateSet('Active','All','Suspended')]
        [string]$Suspended = 'Active',
        [string]$Config,
        [string]$ServiceAccountPath
    )

    $ctx   = Get-GlicContext -ConfigPath $Config -ServiceAccountPath $ServiceAccountPath
    $uri   = 'https://admin.googleapis.com/admin/directory/v1/users'
    $query = @{ customer = $ctx.CustomerId; maxResults = 500; projection = 'full' }
    if ($OrgUnit) { $query['query'] = "orgUnitPath='$($OrgUnit -replace "'","\\'")'" }
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')

    Invoke-GlicPagedRequest -Uri $uri -Headers $ctx.Headers -Query $query -ItemsProperty 'users' |
    ForEach-Object {
        $isSuspended = $_.suspended -eq $true
        if ($Suspended -eq 'Active'    -and $isSuspended)  { return }
        if ($Suspended -eq 'Suspended' -and -not $isSuspended) { return }

        $org        = $_.organizations | Where-Object { $_.primary -eq $true } | Select-Object -First 1
        if (-not $org) { $org = $_.organizations | Select-Object -First 1 }
        $managerEmail = ($_.relations | Where-Object { $_.type -eq 'manager' } | Select-Object -First 1).value
        $employeeId   = ($_.externalIds | Where-Object { $_.type -eq 'organization' } | Select-Object -First 1).value
        $aliases      = ($_.aliases -join ';')
        $creation     = if ($_.creationTimeRaw)  { [DateTimeOffset]::Parse($_.creationTimeRaw) }  else { $null }
        $lastLogin    = if ($_.lastLoginTimeRaw) { [DateTimeOffset]::Parse($_.lastLoginTimeRaw) } else { $null }

        [PSCustomObject]@{
            ReportDate       = $reportDate
            CustomerId       = $ctx.CustomerId
            PrimaryEmail     = if ($_.primaryEmail)     { $_.primaryEmail }         else { '' }
            FullName         = if ($_.name)             { $_.name.fullName }        else { '' }
            GivenName        = if ($_.name)             { $_.name.givenName }       else { '' }
            FamilyName       = if ($_.name)             { $_.name.familyName }      else { '' }
            CreationTime     = $creation
            LastLoginTime    = $lastLogin
            IsEnrolledIn2Sv  = $_.isEnrolledIn2Sv
            IsEnforcedIn2Sv  = $_.isEnforcedIn2Sv
            RecoveryEmail    = if ($_.recoveryEmail)    { $_.recoveryEmail }        else { '' }
            RecoveryPhone    = if ($_.recoveryPhone)    { $_.recoveryPhone }        else { '' }
            OrgUnit          = if ($_.orgUnitPath)      { $_.orgUnitPath }          else { '' }
            IsAdmin          = $_.isAdmin
            IsDelegatedAdmin = $_.isDelegatedAdmin
            Suspended        = $_.suspended
            Archived         = $_.archived
            Department       = if ($org)                { $org.department }         else { '' }
            JobTitle         = if ($org)                { $org.title }              else { '' }
            CostCenter       = if ($org)                { $org.costCenter }         else { '' }
            EmployeeId       = if ($employeeId)         { $employeeId }             else { '' }
            ManagerEmail     = if ($managerEmail)       { $managerEmail }           else { '' }
            Aliases          = $aliases
        }
    }
}
