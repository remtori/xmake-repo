package("libpng")
    set_homepage("http://www.libpng.org/pub/png/libpng.html")
    set_description("The official PNG reference library")
    set_license("libpng-2.0")

    add_urls("https://github.com/glennrp/libpng/archive/refs/tags/$(version).tar.gz")
    add_urls("https://github.com/glennrp/libpng.git")

    add_versions("v1.6.44", "0ef5b633d0c65f780c4fced27ff832998e71478c13b45dfb6e94f23a82f64f7c")
    add_versions("v1.6.43", "fecc95b46cf05e8e3fc8a414750e0ba5aad00d89e9fdf175e94ff041caf1a03a")
    add_versions("v1.6.42", "fe89de292e223829859d21990d9c4d6b7e30e295a268f6a53a022611aa98bd67")
    add_versions("v1.6.40", "62d25af25e636454b005c93cae51ddcd5383c40fa14aa3dae8f6576feb5692c2")
    add_versions("v1.6.37", "ca74a0dace179a8422187671aee97dd3892b53e168627145271cad5b5ac81307")
    add_versions("v1.6.36", "5bef5a850a9255365a2dc344671b7e9ef810de491bd479c2506ac3c337e2d84f")
    add_versions("v1.6.35", "6d59d6a154ccbb772ec11772cb8f8beb0d382b61e7ccc62435bf7311c9f4b210")
    add_versions("v1.6.34", "e45ce5f68b1d80e2cb9a2b601605b374bdf51e1798ef1c2c2bd62131dfcf9eef")

    add_deps("zlib")

    if is_plat("linux") then
        add_syslinks("m")
    end

    on_install(function (package)
        local configs = {}
        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:debug() and "Debug" or "Release"))
        table.insert(configs, "-DPNG_SHARED=" .. (package:config("shared") and "ON" or "OFF"))
        import("package.tools.cmake").install(package, configs)
    end)

    on_test(function (package)
        assert(package:has_cfuncs("png_create_read_struct", {includes = "png.h"}))
    end)
