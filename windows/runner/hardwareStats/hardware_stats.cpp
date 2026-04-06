#include "HardwareStats.h"

#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <comdef.h>
#include <wbemidl.h>
#include <powrprof.h>
#include <psapi.h>

#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "wbemuuid.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "powrprof.lib")

// ─────────────────────────────────────────────
// CPU Usage  (PDH)
// ─────────────────────────────────────────────
double HardwareStats::GetCpuUsage() {
    static PDH_HQUERY   query   = nullptr;
    static PDH_HCOUNTER counter = nullptr;

    if (!query) {
        PdhOpenQuery(nullptr, 0, &query);
        PdhAddEnglishCounterW(query, L"\\Processor(_Total)\\% Processor Time", 0, &counter);
        PdhCollectQueryData(query);
        Sleep(100);
    }

    PdhCollectQueryData(query);
    PDH_FMT_COUNTERVALUE val{};
    PdhGetFormattedCounterValue(counter, PDH_FMT_DOUBLE, nullptr, &val);
    return val.doubleValue;
}

// ─────────────────────────────────────────────
// Battery Level
// ─────────────────────────────────────────────
int HardwareStats::GetBatteryLevel() {
    SYSTEM_POWER_STATUS sps{};
    if (!GetSystemPowerStatus(&sps)) return -1;
    if (sps.BatteryLifePercent == 255) return -1;
    return static_cast<int>(sps.BatteryLifePercent);
}

// ─────────────────────────────────────────────
// Memory Usage (MB)
// ─────────────────────────────────────────────
int HardwareStats::GetMemoryUsageMB() {
    MEMORYSTATUSEX ms{};
    ms.dwLength = sizeof(ms);
    if (!GlobalMemoryStatusEx(&ms)) return -1;
    return static_cast<int>((ms.ullTotalPhys - ms.ullAvailPhys) / 1024 / 1024);
}

// ─────────────────────────────────────────────
// Fan Speed  (WMI)
// ─────────────────────────────────────────────
static int QueryWmiFanSpeed() {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    bool uninit = SUCCEEDED(hr);
    CoInitializeSecurity(nullptr, -1, nullptr, nullptr,
                         RPC_C_AUTHN_LEVEL_DEFAULT, RPC_C_IMP_LEVEL_IMPERSONATE,
                         nullptr, EOAC_NONE, nullptr);

    IWbemLocator*  pLoc = nullptr;
    IWbemServices* pSvc = nullptr;
    int fanSpeed = -1;

    hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
                          IID_IWbemLocator, reinterpret_cast<void**>(&pLoc));
    if (FAILED(hr)) goto cleanup;

    hr = pLoc->ConnectServer(_bstr_t(L"ROOT\\CIMV2"), nullptr, nullptr, nullptr,
                             0, nullptr, nullptr, &pSvc);
    if (FAILED(hr)) goto cleanup;

    {
        IEnumWbemClassObject* pEnum = nullptr;
        hr = pSvc->ExecQuery(_bstr_t(L"WQL"),
                             _bstr_t(L"SELECT DesiredSpeed FROM Win32_Fan"),
                             WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                             nullptr, &pEnum);
        if (SUCCEEDED(hr) && pEnum) {
            IWbemClassObject* pObj = nullptr; ULONG ret = 0;
            if (pEnum->Next(WBEM_INFINITE, 1, &pObj, &ret) == S_OK && ret > 0) {
                VARIANT v; VariantInit(&v);
                if (SUCCEEDED(pObj->Get(L"DesiredSpeed", 0, &v, nullptr, nullptr)))
                    if (v.vt == VT_I4 || v.vt == VT_UI4) fanSpeed = static_cast<int>(v.lVal);
                VariantClear(&v); pObj->Release();
            }
            pEnum->Release();
        }
    }

    cleanup:
    if (pSvc) pSvc->Release();
    if (pLoc) pLoc->Release();
    if (uninit) CoUninitialize();
    return fanSpeed;
}

int HardwareStats::GetFanSpeed() { return QueryWmiFanSpeed(); }

// ─────────────────────────────────────────────
// CPU Temperature  (WMI ACPI)
// ─────────────────────────────────────────────
static double QueryWmiCpuTemp() {
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    bool uninit = SUCCEEDED(hr);
    CoInitializeSecurity(nullptr, -1, nullptr, nullptr,
                         RPC_C_AUTHN_LEVEL_DEFAULT, RPC_C_IMP_LEVEL_IMPERSONATE,
                         nullptr, EOAC_NONE, nullptr);

    IWbemLocator*  pLoc = nullptr;
    IWbemServices* pSvc = nullptr;
    double tempC = -1.0;

    hr = CoCreateInstance(CLSID_WbemLocator, nullptr, CLSCTX_INPROC_SERVER,
                          IID_IWbemLocator, reinterpret_cast<void**>(&pLoc));
    if (FAILED(hr)) goto cleanup;

    hr = pLoc->ConnectServer(_bstr_t(L"ROOT\\WMI"), nullptr, nullptr, nullptr,
                             0, nullptr, nullptr, &pSvc);
    if (FAILED(hr)) goto cleanup;

    {
        IEnumWbemClassObject* pEnum = nullptr;
        hr = pSvc->ExecQuery(_bstr_t(L"WQL"),
                             _bstr_t(L"SELECT CurrentTemperature FROM MSAcpi_ThermalZoneTemperature"),
                             WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY,
                             nullptr, &pEnum);
        if (SUCCEEDED(hr) && pEnum) {
            IWbemClassObject* pObj = nullptr; ULONG ret = 0;
            if (pEnum->Next(WBEM_INFINITE, 1, &pObj, &ret) == S_OK && ret > 0) {
                VARIANT v; VariantInit(&v);
                if (SUCCEEDED(pObj->Get(L"CurrentTemperature", 0, &v, nullptr, nullptr)))
                    if (v.vt == VT_I4 || v.vt == VT_UI4)
                        tempC = (static_cast<double>(v.lVal) / 10.0) - 273.15;
                VariantClear(&v); pObj->Release();
            }
            pEnum->Release();
        }
    }

    cleanup:
    if (pSvc) pSvc->Release();
    if (pLoc) pLoc->Release();
    if (uninit) CoUninitialize();
    return tempC;
}

double HardwareStats::GetCpuTemperature() { return QueryWmiCpuTemp(); }