#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

__attribute__((constructor))
static void uuyc_env_inject(void) {
    // 1. 日志基准目录，必须指向可写目录，避免向只读的 /nix/store 写入导致 std_exception
    setenv("NRD_LOG_ROOT", "/var/log/uuyc", 1);

    // 2. SSL/TLS 证书路径，确保 libcurl 和网络通信正常进行 TLS 握手
    setenv("SSL_CERT_FILE", "@cacert@/etc/ssl/certs/ca-bundle.crt", 1);
    setenv("SSL_CERT_DIR", "/etc/ssl/certs", 1);
    setenv("CURL_CA_BUNDLE", "@cacert@/etc/ssl/certs/ca-bundle.crt", 1);

    // 3. D-Bus 系统总线地址
    setenv("DBUS_SYSTEM_BUS_ADDRESS", "unix:path=/run/dbus/system_bus_socket", 0);

    // 4. PipeWire / SPA 插件及 Terminfo 路径
    setenv("PIPEWIRE_MODULE_DIR", "@out@/opt/uuyc/lib/pipewire-0.3", 1);
    setenv("PIPEWIRE_CONFIG_PREFIX", "@out@/opt/uuyc/share/pipewire", 1);
    setenv("SPA_PLUGIN_DIR", "@out@/opt/uuyc/lib/spa-0.2", 1);
    setenv("TERMINFO_DIRS", "@out@/opt/uuyc/share/terminfo", 1);

    // 5. 补齐 PATH 环境变量（拼接 NixOS 的系统二进制路径）
    const char *orig_path = getenv("PATH");
    char new_path[4096];
    if (orig_path && strlen(orig_path) > 0) {
        snprintf(new_path, sizeof(new_path), "%s:%s", "@binPath@", orig_path);
    } else {
        snprintf(new_path, sizeof(new_path), "%s:/usr/local/bin:/usr/bin:/bin", "@binPath@");
    }
    setenv("PATH", new_path, 1);

    // 6. 补齐 LD_LIBRARY_PATH 环境变量（加入宿主机 GPU 驱动路径 /run/opengl-driver/lib）
    const char *orig_ld = getenv("LD_LIBRARY_PATH");
    char new_ld[4096];
    if (orig_ld && strlen(orig_ld) > 0) {
        if (!strstr(orig_ld, "/run/opengl-driver/lib")) {
            snprintf(new_ld, sizeof(new_ld), "/run/opengl-driver/lib:%s", orig_ld);
            setenv("LD_LIBRARY_PATH", new_ld, 1);
        }
    } else {
        setenv("LD_LIBRARY_PATH", "/run/opengl-driver/lib:@out@/opt/uuyc/lib", 1);
    }

    fprintf(stderr, "[uuyc-env-inject] initialized environment (PID=%d, EUID=%d, NRD_LOG_ROOT=%s)\n",
            getpid(), geteuid(), getenv("NRD_LOG_ROOT"));
}
