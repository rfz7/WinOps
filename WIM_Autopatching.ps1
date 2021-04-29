$monthofinterest = @('2017-Apr' , 
    '2017-May', 
    '2017-Jun', 
    '2017-Jul', 
    '2017-Aug', 
    '2017-Sep', 
    '2017-Oct', 
    '2017-Nov', 
    '2017-Dec', 
    '2018-Jan', 
    '2018-Feb', 
    '2018-Mar', 
    '2018-Apr', 
    '2018-May', 
    '2018-Jun', 
    '2018-Jul', 
    '2018-Aug', 
    '2018-Sep', 
    '2018-Oct', 
    '2018-Nov', 
    '2018-Dec', 
    '2019-Jan', 
    '2019-Feb', 
    '2019-Mar', 
    '2019-Apr', 
    '2019-May', 
    '2019-Jun', 
    '2019-Jul'  )
$colls = @()
$monthofinterest | . {
    process
    {
        $pcdReport = Invoke-RestMethod -Method Get -Uri "https://api.msrc.microsoft.com/cvrf/$($2019-Jul'?api-version=2018" -Headers @{
            'api-key' = '<APIKey>'
        }
        $pcdReport.cvrfdoc.Vulnerability.cve | . {
            process
            {
                $results = Invoke-RestMethod -Uri "https://portal.msrc.microsoft.com/api/security-guidance/en-US/CVE/$($_)"
                $results
                $colls += $results
            }
        }
    }
}
$colls | 
Select-Object cve* -ExpandProperty affectedproducts | 
Export-Csv C:\Temp\MSRCRawReport.csv -NoTypeInformatio