#include "pch.h"

#include <windows.h>
#include <dxgi1_6.h>

#define DLL_EXPORT __declspec(dllexport)

#pragma comment(lib, "dxgi.lib")

extern "C"
{
    DLL_EXPORT bool IsHDREnabled()
    {
        // Initialize COM
        HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        if (FAILED(hr))
        {
            return false;
        }

        IDXGIFactory1* pFactory = nullptr;
        IDXGIAdapter1* pAdapter = nullptr;
        IDXGIOutput* pOutput = nullptr;
        IDXGIOutput6* pOutput6 = nullptr;
        bool isHDREnabled = false;

        // Create DXGI factory
        hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&pFactory);
        if (FAILED(hr))
        {
            CoUninitialize();
            return false;
        }

        // Enumerate all adapters
        for (UINT adapterIndex = 0;
            !isHDREnabled && SUCCEEDED(pFactory->EnumAdapters1(adapterIndex, &pAdapter));
            ++adapterIndex)
        {
            // Enumerate all outputs for this adapter
            for (UINT outputIndex = 0;
                !isHDREnabled && SUCCEEDED(pAdapter->EnumOutputs(outputIndex, &pOutput));
                ++outputIndex)
            {
                // Get IDXGIOutput6 interface
                hr = pOutput->QueryInterface(__uuidof(IDXGIOutput6), (void**)&pOutput6);
                if (SUCCEEDED(hr))
                {
                    // Get HDR capability
                    DXGI_OUTPUT_DESC1 desc;
                    hr = pOutput6->GetDesc1(&desc);
                    if (SUCCEEDED(hr))
                    {
                        // Check if HDR is enabled
                        isHDREnabled = desc.ColorSpace == DXGI_COLOR_SPACE_RGB_FULL_G2084_NONE_P2020;
                    }
                    pOutput6->Release();
                }
                pOutput->Release();
                pOutput = nullptr;
            }
            pAdapter->Release();
            pAdapter = nullptr;
        }

        if (pFactory)
        {
            pFactory->Release();
        }

        CoUninitialize();
        return isHDREnabled;
    }
}
