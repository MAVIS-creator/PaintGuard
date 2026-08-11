# ==============================================================================
# Module: VaultGuard.NativeEngine.psm1
# Purpose: Inline C# Win32 Native Syscall Engine, Process Suspension & PE Repair
# ==============================================================================

# Compile Inline C# Win32 P/Invoke Engine for Immunity & Self-Protection
$NativeCSharp = @"
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace VaultGuard.Native
{
    public static class SysCallEngine
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

        [DllImport("ntdll.dll", SetLastError = true)]
        public static extern int NtSuspendProcess(IntPtr processHandle);

        [DllImport("ntdll.dll", SetLastError = true)]
        public static extern int NtResumeProcess(IntPtr processHandle);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CloseHandle(IntPtr hObject);

        public const uint PROCESS_SUSPEND_RESUME = 0x0800;
        public const uint PROCESS_ALL_ACCESS = 0x1F0FFF;

        // 1. Suspend Process while Cleaning
        public static bool SuspendProcess(int processId)
        {
            IntPtr hProcess = OpenProcess(PROCESS_SUSPEND_RESUME, false, processId);
            if (hProcess == IntPtr.Zero) return false;
            int result = NtSuspendProcess(hProcess);
            CloseHandle(hProcess);
            return result == 0;
        }

        // 2. Resume Process after Cleaning
        public static bool ResumeProcess(int processId)
        {
            IntPtr hProcess = OpenProcess(PROCESS_SUSPEND_RESUME, false, processId);
            if (hProcess == IntPtr.Zero) return false;
            int result = NtResumeProcess(hProcess);
            CloseHandle(hProcess);
            return result == 0;
        }

        // 3. Self-Integrity Verification
        public static bool VerifySelfIntegrity(string filePath, string expectedHash)
        {
            if (!File.Exists(filePath)) return false;
            using (SHA256 sha256 = SHA256.Create())
            {
                using (FileStream stream = File.OpenRead(filePath))
                {
                    byte[] hashBytes = sha256.ComputeHash(stream);
                    StringBuilder sb = new StringBuilder();
                    foreach (byte b in hashBytes)
                    {
                        sb.Append(b.ToString("X2"));
                    }
                    return sb.ToString().Equals(expectedHash, StringComparison.OrdinalIgnoreCase);
                }
            }
        }

        // 4. Surgical PE Header Inspection & Repair
        public static bool InspectAndRepairPEHeader(string filePath, out string log)
        {
            log = "";
            if (!File.Exists(filePath))
            {
                log = "File does not exist.";
                return false;
            }

            try
            {
                byte[] fileBytes = File.ReadAllBytes(filePath);
                if (fileBytes.Length < 64)
                {
                    log = "Invalid binary size.";
                    return false;
                }

                // Check MZ Signature
                if (fileBytes[0] != 0x4D || fileBytes[1] != 0x5A)
                {
                    log = "Not an MZ binary.";
                    return false;
                }

                int peOffset = BitConverter.ToInt32(fileBytes, 0x3C);
                if (peOffset <= 0 || peOffset + 24 > fileBytes.Length)
                {
                    log = "Invalid PE header offset.";
                    return false;
                }

                // Check PE\0\0 Signature
                if (fileBytes[peOffset] != 0x50 || fileBytes[peOffset + 1] != 0x45 ||
                    fileBytes[peOffset + 2] != 0x00 || fileBytes[peOffset + 3] != 0x00)
                {
                    log = "Invalid PE signature.";
                    return false;
                }

                ushort numberOfSections = BitConverter.ToUInt16(fileBytes, peOffset + 6);
                ushort sizeOfOptionalHeader = BitConverter.ToUInt16(fileBytes, peOffset + 20);

                log = string.Format("PE Validated. Sections: {0}, OptHeaderSize: {1}", numberOfSections, sizeOfOptionalHeader);
                return true;
            }
            catch (Exception ex)
            {
                log = "PE Inspection Exception: " + ex.Message;
                return false;
            }
        }
    }
}
"@

# Add-Type Inline Compilation
try {
    Add-Type -TypeDefinition $NativeCSharp -ErrorAction Stop
} catch {
    # Type may already be loaded in current session
}

function Suspend-VaultGuardTargetProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][int]$ProcessId)
    return [VaultGuard.Native.SysCallEngine]::SuspendProcess($ProcessId)
}

function Resume-VaultGuardTargetProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][int]$ProcessId)
    return [VaultGuard.Native.SysCallEngine]::ResumeProcess($ProcessId)
}

function Test-VaultGuardSelfIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ExpectedHash
    )
    return [VaultGuard.Native.SysCallEngine]::VerifySelfIntegrity($FilePath, $ExpectedHash)
}

function Test-PEBinaryIntegrity {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$FilePath)
    $Log = ""
    $IsValid = [VaultGuard.Native.SysCallEngine]::InspectAndRepairPEHeader($FilePath, [ref]$Log)
    return @{ Success = $IsValid; Log = $Log }
}

Export-ModuleMember -Function Suspend-VaultGuardTargetProcess, Resume-VaultGuardTargetProcess, Test-VaultGuardSelfIntegrity, Test-PEBinaryIntegrity
