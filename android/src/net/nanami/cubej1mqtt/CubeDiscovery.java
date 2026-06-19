package net.nanami.cubej1mqtt;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.util.Log;

import java.net.InetAddress;
import java.util.HashMap;
import java.util.Map;

public final class CubeDiscovery {
    private static final String TAG = "CubeDiscovery";
    private static final String SERVICE_TYPE = "_cubej1-mqtt._tcp.";

    private static NsdManager nsdManager;
    private static NsdManager.DiscoveryListener discoveryListener;
    private static final Map<String, NsdManager.ResolveListener> pendingResolves = new HashMap<>();
    private static WifiManager.MulticastLock multicastLock;

    private CubeDiscovery() {
    }

    public static synchronized void startDiscovery(Context context) {
        stopDiscovery();
        log("Starting discovery for " + SERVICE_TYPE);

        if (context == null) {
            log("Qt context is null");
            nativeSetScanning(false);
            return;
        }

        nsdManager = (NsdManager) context.getSystemService(Context.NSD_SERVICE);
        if (nsdManager == null) {
            log("NsdManager is unavailable");
            nativeSetScanning(false);
            return;
        }

        WifiManager wifiManager = (WifiManager) context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifiManager != null) {
            multicastLock = wifiManager.createMulticastLock("cubej1mqtt-discovery");
            multicastLock.setReferenceCounted(false);
            multicastLock.acquire();
            log("Acquired multicast lock");
        }

        discoveryListener = new NsdManager.DiscoveryListener() {
            @Override
            public void onStartDiscoveryFailed(String serviceType, int errorCode) {
                log("onStartDiscoveryFailed type=" + serviceType + " code=" + errorCode);
                nativeSetScanning(false);
            }

            @Override
            public void onStopDiscoveryFailed(String serviceType, int errorCode) {
                log("onStopDiscoveryFailed type=" + serviceType + " code=" + errorCode);
                nativeSetScanning(false);
            }

            @Override
            public void onDiscoveryStarted(String serviceType) {
                log("onDiscoveryStarted type=" + serviceType);
                nativeSetScanning(true);
            }

            @Override
            public void onDiscoveryStopped(String serviceType) {
                log("onDiscoveryStopped type=" + serviceType);
                nativeSetScanning(false);
            }

            @Override
            public void onServiceFound(NsdServiceInfo serviceInfo) {
                log("onServiceFound name=" + serviceInfo.getServiceName()
                        + " type=" + serviceInfo.getServiceType());
                if (!matchesServiceType(serviceInfo.getServiceType())) {
                    log("Ignoring unmatched service type");
                    return;
                }
                resolve(serviceInfo);
            }

            @Override
            public void onServiceLost(NsdServiceInfo serviceInfo) {
                log("onServiceLost name=" + serviceInfo.getServiceName()
                        + " type=" + serviceInfo.getServiceType());
                String host = serviceInfo.getHost() != null ? serviceInfo.getHost().getHostAddress() : "";
                nativeDeviceLost(host, serviceInfo.getPort());
            }
        };

        nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener);
    }

    public static synchronized void stopDiscovery() {
        log("Stopping discovery");
        if (nsdManager != null && discoveryListener != null) {
            try {
                nsdManager.stopServiceDiscovery(discoveryListener);
            } catch (Exception ignored) {
                Log.w(TAG, "stopServiceDiscovery threw", ignored);
                log("stopServiceDiscovery threw " + ignored.getClass().getSimpleName());
            }
        }

        pendingResolves.clear();
        discoveryListener = null;
        nsdManager = null;
        releaseMulticastLock();
        nativeSetScanning(false);
    }

    private static synchronized void resolve(final NsdServiceInfo serviceInfo) {
        if (nsdManager == null) {
            log("resolve skipped because NsdManager is null");
            return;
        }

        final String key = serviceInfo.getServiceName() + "|" + serviceInfo.getServiceType();
        if (pendingResolves.containsKey(key)) {
            log("resolve skipped for pending service " + key);
            return;
        }

        NsdManager.ResolveListener listener = new NsdManager.ResolveListener() {
            @Override
            public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
                log("onResolveFailed name=" + serviceInfo.getServiceName()
                        + " type=" + serviceInfo.getServiceType()
                        + " code=" + errorCode);
                pendingResolves.remove(key);
            }

            @Override
            public void onServiceResolved(NsdServiceInfo resolved) {
                pendingResolves.remove(key);
                InetAddress host = resolved.getHost();
                if (host == null) {
                    log("Resolved service has no host");
                    return;
                }

                String address = host.getHostAddress();
                if (address == null || address.isEmpty()) {
                    log("Resolved service has empty host address");
                    return;
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    for (InetAddress candidate : resolved.getHostAddresses()) {
                        if (candidate != null
                                && candidate.getHostAddress() != null
                                && candidate instanceof java.net.Inet4Address) {
                            address = candidate.getHostAddress();
                            break;
                        }
                    }
                }

                log("onServiceResolved name=" + resolved.getServiceName()
                        + " host=" + address + " port=" + resolved.getPort());
                nativeDeviceFound(resolved.getServiceName(), address, resolved.getPort());
            }
        };

        pendingResolves.put(key, listener);
        log("Resolving service " + key);
        nsdManager.resolveService(serviceInfo, listener);
    }

    private static boolean matchesServiceType(String actualType) {
        if (actualType == null) {
            return false;
        }

        String normalized = actualType.endsWith(".") ? actualType : actualType + ".";
        return normalized.equalsIgnoreCase(SERVICE_TYPE)
                || normalized.startsWith("_cubej1-mqtt._tcp");
    }

    private static void releaseMulticastLock() {
        if (multicastLock != null && multicastLock.isHeld()) {
            multicastLock.release();
            log("Released multicast lock");
        }
        multicastLock = null;
    }

    private static void log(String message) {
        Log.i(TAG, message);
        nativeDebugMessage(message);
    }

    private static native void nativeSetScanning(boolean scanning);
    private static native void nativeDeviceFound(String name, String host, int port);
    private static native void nativeDeviceLost(String host, int port);
    private static native void nativeDebugMessage(String message);
}
