#pragma once

#include <windows.h>

class HardwareStats {
public:
    static double  GetCpuUsage();
    static int     GetBatteryLevel();
    static int     GetMemoryUsageMB();
    static int     GetFanSpeed();
    static double  GetCpuTemperature();
};