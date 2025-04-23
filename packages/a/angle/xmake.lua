package("angle")
    set_homepage("https://chromium.googlesource.com/angle/angle")
    set_description("ANGLE - Almost Native Graphics Layer Engine")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/google/angle.git")
    add_versions("6834", "ce13a00a2b049a1ef5e0e70a3d333ce70838ef7b")

    add_deps("python 3.x", {kind = "binary"})
    add_deps("zlib")

    -- Add ANGLE build options based on GN args
    add_configs("enable_null", {description = "Enable null backend", default = true, type = "boolean"})
    add_configs("enable_d3d9", {description = "Enable D3D9 backend", default = is_plat("windows"), type = "boolean"})
    add_configs("enable_d3d11", {description = "Enable D3D11 backend", default = is_plat("windows"), type = "boolean"})
    add_configs("enable_gl", {description = "Enable OpenGL backend", default = not is_plat("windows", "uwp") and not is_plat("iphoneos"), type = "boolean"})
    add_configs("enable_metal", {description = "Enable Metal backend", default = is_plat("macosx") or is_plat("iphoneos"), type = "boolean"})
    add_configs("enable_vulkan", {description = "Enable Vulkan backend", default = is_plat("windows", "linux", "android", "macosx"), type = "boolean"})
    add_configs("enable_hlsl", {description = "Enable HLSL translator", default = is_plat("windows"), type = "boolean"})
    add_configs("enable_essl", {description = "Enable ESSL translator", default = true, type = "boolean"})
    add_configs("enable_glsl", {description = "Enable GLSL translator", default = true, type = "boolean"})

    if is_plat("windows") then
        add_links("libEGL", "libGLESv2", "libANGLE")
        add_syslinks("user32", "gdi32", "dxgi", "dxguid", "d3d9", "delayimp")
        add_ldflags("/DELAYLOAD:d3d9.dll")
    else
        if is_plat("macosx") then
            add_syslinks("objc")
            add_frameworks("CoreFoundation", "CoreGraphics", "IOKit", "Metal", "IOSurface", "QuartzCore", "Cocoa")
        end
        if is_plat("linux") then
            add_deps("libx11", "libxext", "libxi")
        end
        add_links("EGL", "GLESv2", "ANGLE")
    end

    on_load(function (package)
        if not package:config("shared") then
            package:add("defines", "KHRONOS_STATIC")
        end
    end)

    on_install(function (package)
        -- Setup GN arguments
        local args = {}

        -- Core library options
        table.insert(args, "is_debug=" .. (package:debug() and "true" or "false"))
        table.insert(args, "is_component_build=" .. (package:config("shared") and "true" or "false"))

        -- ANGLE backend options
        table.insert(args, "angle_enable_null=" .. (package:config("enable_null") and "true" or "false"))
        table.insert(args, "angle_enable_d3d9=" .. (package:config("enable_d3d9") and "true" or "false"))
        table.insert(args, "angle_enable_d3d11=" .. (package:config("enable_d3d11") and "true" or "false"))
        table.insert(args, "angle_enable_gl=" .. (package:config("enable_gl") and "true" or "false"))
        table.insert(args, "angle_enable_metal=" .. (package:config("enable_metal") and "true" or "false"))
        table.insert(args, "angle_enable_vulkan=" .. (package:config("enable_vulkan") and "true" or "false"))

        -- Translator options
        table.insert(args, "angle_enable_hlsl=" .. (package:config("enable_hlsl") and "true" or "false"))
        table.insert(args, "angle_enable_essl=" .. (package:config("enable_essl") and "true" or "false"))
        table.insert(args, "angle_enable_glsl=" .. (package:config("enable_glsl") and "true" or "false"))

        -- Additional common args
        table.insert(args, "angle_has_histograms=false")
        table.insert(args, "angle_standalone=true")
        table.insert(args, "angle_use_x11=" .. (is_plat("linux") and "true" or "false"))

        -- Configure and build with GN
        local configs = {}
        if package:is_plat("windows") then
            configs.vs_runtime = package:config("vs_runtime")
        end

        import("package.tools.gn").build(package, args, {
            buildir = "out",
            envs = os.joinenvs(
                os.getenvs(),
                {
                    PATH = package:dep("python"):installdir("bin") .. ";" .. os.getenv("PATH"),
                }
            )
        })

        -- Install headers
        os.cp("include", package:installdir())

        -- Install libraries
        local libsuffix = package:debug() and "d" or ""
        local libdir = "out/Default"

        if package:is_plat("windows") then
            if package:config("shared") then
                os.cp(libdir .. "/*.dll", package:installdir("bin"))
            end
            os.cp(libdir .. "/*.lib", package:installdir("lib"))
        else
            if package:config("shared") then
                os.cp(libdir .. "/*.so", package:installdir("lib"))
                os.cp(libdir .. "/*.dylib", package:installdir("lib"))
            else
                os.cp(libdir .. "/*.a", package:installdir("lib"))
            end
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <EGL/egl.h>
            void test() {
                const char *extensionString =
                    static_cast<const char *>(eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS));
                EGLint res = eglGetError();
            }
        ]]}, {configs = {languages = "c++11"}}))
    end)
