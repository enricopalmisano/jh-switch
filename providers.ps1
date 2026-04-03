# Interfaccia base per i provider JDK
class JdkProvider {
    [string]$Name
    [string[]]$Aliases
    
    JdkProvider([string]$name, [string[]]$aliases) {
        $this.Name = $name
        $this.Aliases = $aliases
    }
    
    # Metodo astratto: ottenere le versioni disponibili
    [string[]] GetAvailableMajors() {
        throw "This method must be implemented by subclasses"
    }
    
    # Metodo astratto: risolvere un nome in dettagli di installazione
    [object] ResolveInstall([string]$inputName) {
        throw "This method must be implemented by subclasses"
    }
    
    # Metodo astratto: verificare se un nome è valido per questo provider
    [bool] CanHandle([string]$inputName) {
        throw "This method must be implemented by subclasses"
    }
    
    # Metodo helper: ottenere tutti i nomi validi (inclusi alias)
    [string[]] GetAllValidNames([string]$major) {
        $names = @("$($this.Name)-$major")
        foreach ($alias in $this.Aliases) {
            $names += "$alias-$major"
        }
        return $names
    }
}

# Provider per Amazon Corretto
class CorrettoProvider : JdkProvider {
    CorrettoProvider() : base("corretto", @("amazon-corretto")) {}
    
    [string[]] GetAvailableMajors() {
        try {
            $content = (Invoke-WebRequest -UseBasicParsing -Uri "https://corretto.aws/downloads/").Content
            $ms = [regex]::Matches($content, "corretto-(\d+)-ug")
            $majors = @{}
            foreach ($m in $ms) { $majors[$m.Groups[1].Value] = $true }
            return @($majors.Keys | Sort-Object {[int]$_})
        } catch {
            return @("8", "11", "17", "21", "22")
        }
    }
    
    [bool] CanHandle([string]$inputName) {
        $name = $inputName.Trim().ToLowerInvariant()
        return ($name -match '^(?:amazon-)?corretto-(\d+)$' -or $name -match '^(\d+)$')
    }
    
    [object] ResolveInstall([string]$inputName) {
        $name = $inputName.Trim().ToLowerInvariant()
        $major = $null
        
        if ($name -match '^(?:amazon-)?corretto-(\d+)$') {
            $major = $Matches[1]
        } elseif ($name -match '^(\d+)$') {
            $major = $Matches[1]
        }
        
        if ($major) {
            return @{
                Provider = $this.Name
                FolderName = "corretto-$major"
                DownloadUrl = "https://corretto.aws/downloads/latest/amazon-corretto-$major-x64-windows-jdk.zip"
                Major = $major
            }
        }
        return $null
    }
}

# Provider per Microsoft Build of OpenJDK
class MicrosoftProvider : JdkProvider {
    MicrosoftProvider() : base("microsoft-jdk", @("ms-jdk", "msopenjdk", "ms")) {}
    
    [string[]] GetAvailableMajors() {
        try {
            $content = (Invoke-WebRequest -UseBasicParsing -Uri "https://learn.microsoft.com/en-us/java/openjdk/download").Content
            $ms = [regex]::Matches($content, "microsoft-jdk-(\d+)(?:\.\d+)*-windows-x64\.zip")
            $majors = @{}
            foreach ($m in $ms) { $majors[$m.Groups[1].Value] = $true }
            if ($majors.Count -gt 0) {
                return @($majors.Keys | Sort-Object {[int]$_})
            }
        } catch {}
        return @("11", "17", "21", "25")
    }
    
    [bool] CanHandle([string]$inputName) {
        $name = $inputName.Trim().ToLowerInvariant()
        return ($name -match '^(?:microsoft-jdk|ms-?jdk|msopenjdk)-(\d+)$')
    }
    
    [object] ResolveInstall([string]$inputName) {
        $name = $inputName.Trim().ToLowerInvariant()
        if ($name -match '^(?:microsoft-jdk|ms-?jdk|msopenjdk)-(\d+)$') {
            $major = $Matches[1]
            return @{
                Provider = $this.Name
                FolderName = "microsoft-jdk-$major"
                DownloadUrl = "https://aka.ms/download-jdk/microsoft-jdk-$major-windows-x64.zip"
                Major = $major
            }
        }
        return $null
    }
}

# Registry dei provider - gestore centrale delle Strategy
class ProviderRegistry {
    [JdkProvider[]]$Providers
    
    ProviderRegistry() {
        $this.Providers = @(
            [CorrettoProvider]::new(),
            [MicrosoftProvider]::new()
        )
    }
    
    [JdkProvider] FindProvider([string]$inputName) {
        foreach ($provider in $this.Providers) {
            if ($provider.CanHandle($inputName)) {
                return $provider
            }
        }
        return $null
    }
    
    [object] ResolveInstall([string]$inputName) {
        $provider = $this.FindProvider($inputName)
        if ($provider) {
            return $provider.ResolveInstall($inputName)
        }
        return $null
    }
    
    [hashtable] GetAllAvailableJdks() {
        $result = @{}
        foreach ($provider in $this.Providers) {
            $majors = $provider.GetAvailableMajors()
            $providerName = $provider.Name
            $result[$providerName] = @{
                Provider = $provider
                Majors = $majors
                DisplayNames = @($majors | ForEach-Object { "$providerName-$_" })
            }
        }
        return $result
    }
    
    [void] AddProvider([JdkProvider]$provider) {
        $this.Providers += $provider
    }
}

# Funzione globale per ottenere il registry
function Get-ProviderRegistry {
    return [ProviderRegistry]::new()
}
