package('skia')
    local commits = {
        ["132"] = "07f41bcb8ee32fd84ae845095d49055d5122e606",
    }

    add_urls("https://github.com/google/skia/archive/$(version).zip", {version = function (version) return commits[tostring(version)] end})

    add_versions("132", "1246975f106a2fc98a167bf5d56053a6e8618e42db0394228c6f152daa298116")

    if is_plat("windows") then
        add_syslinks("gdi32", "user32", "opengl32")
    elseif is_plat("macosx") then
        add_frameworks("CoreFoundation", "CoreGraphics", "CoreText", "CoreServices")
    elseif is_plat("linux") then
        add_syslinks("pthread", "GL", "dl", "rt")
    end

    add_includedirs("include", "include/..", "include/ports")

    add_links("skia")

	local external_deps = {
        'icu4c',
		'freetype',
		'harfbuzz',
		'libheif',
		'expat',
		'libjpeg-turbo',
		'libpng',
		'libwebp',
		'zlib',
	}

    if (is_plat("windows")) then
        table.insert(external_deps, 'dlfcn-win32')
    end

	add_deps(table.unpack(external_deps))

    on_load(function (package)
        if package:is_built() then
            package:add("deps", "gn")
            package:add("deps", "python")
            package:add("deps", "ninja")
        end
    end)

    on_install(function (package)
        local args = {is_official_build = true,
                      is_component_build = package:config("shared"),
                      is_debug = package:debug(),
                      skia_enable_tools = false,
                      skia_use_icu = true,
					  skia_use_system_icu = true,
                      skia_use_sfntly = false,
                      skia_use_piex = false,
                      skia_use_freetype = true,
                      skia_use_system_freetype2 = true,
                      skia_use_harfbuzz = true,
					  skia_use_system_harfbuzz = true,
                      skia_use_libheif = true,
					  skia_use_system_libheif = true,
                      skia_use_expat = true,
					  skia_use_system_expat = true,
                      skia_use_libjpeg_turbo_decode = true,
                      skia_use_libjpeg_turbo_encode = true,
					  skia_use_system_libjpeg_turbo = true,
                      skia_use_libpng_decode = true,
                      skia_use_libpng_encode = true,
					  skia_use_system_libpng = true,
                      skia_use_libwebp_decode = true,
                      skia_use_libwebp_encode = true,
					  skia_use_system_libwebp = true,
                      skia_use_zlib = true,
					  skia_use_system_zlib = true,
					  skia_enable_gpu = true,
                      skia_enable_pdf = false}

        -- fix symbol lookup error: /lib64/libk5crypto.so.3: undefined symbol: EVP_KDF_ctrl, version OPENSSL_1_1_1b
        local LD_LIBRARY_PATH
        if package:is_plat("linux") and linuxos.name() == "fedora" then
            LD_LIBRARY_PATH = os.getenv("LD_LIBRARY_PATH")
            if LD_LIBRARY_PATH then
                local libdir = os.arch() == "x86_64" and "/usr/lib64" or "/usr/lib"
                LD_LIBRARY_PATH = libdir .. ":" .. LD_LIBRARY_PATH
            end
        end

        -- patches
        io.replace("bin/fetch-gn", "import os\n", "import os\nimport ssl\nssl._create_default_https_context = ssl._create_unverified_context\n", {plain = true})
        os.vrunv("python", {"tools/git-sync-deps"}, {
            envs = {
                LD_LIBRARY_PATH = LD_LIBRARY_PATH,
                HTTP_PROXY = os.getenv("HTTP_PROXY"),
                HTTPS_PROXY = os.getenv("HTTPS_PROXY"),
                GIT_SYNC_DEPS_SKIP_EMSDK = tostring(not package:is_plat("wasm")),
            }})

        local skia_gn = "gn/skia/BUILD.gn"
        if not os.exists(skia_gn) then
            skia_gn = "gn/BUILD.gn"
        end

        if package:is_plat("windows") then
            local msvc = package:toolchain("msvc")
            assert(msvc:check(), "vs not found!")

            local msvc_vc = msvc:runenvs()['VCInstallDir']
            local msvc_vc = string.gsub(msvc_vc, "\\", "\\\\")
            io.writefile("gn/find_msvc.py", "print(\"".. msvc_vc .."\")")
        end

        io.replace(skia_gn, "libs += [ \"pthread\" ]", "libs += [ \"pthread\", \"m\", \"stdc++\" ]", {plain = true})
        io.replace("gn/toolchain/BUILD.gn", "$shell $win_sdk/bin/SetEnv.cmd /x86 && ", "", {plain = true})
        io.replace("third_party/externals/dng_sdk/source/dng_pthread.cpp", "auto_ptr", "unique_ptr", {plain = true})
        io.replace("BUILD.gn", 'executable%("skia_c_api_example"%) {.-}', "")

        -- set deps flags
        local cflags = {}
        local ldflags = {}

        if package:is_plat("windows") then
            local vs_runtime = package:config("vs_runtime")
            if (vs_runtime ~= nil) and (vs_runtime ~= '') then
                table.insert(cflags, "-" .. vs_runtime)
            end
        end

		for _, depname in ipairs(external_deps) do
			local fetchinfo = package:dep(depname):fetch()
			if fetchinfo then
				for _, includedir in ipairs(fetchinfo.includedirs or fetchinfo.sysincludedirs) do
					table.insert(cflags, "-I" .. includedir)
				end
				for _, linkdir in ipairs(fetchinfo.linkdirs) do
					table.insert(ldflags, "-L" .. linkdir)
				end
				for _, link in ipairs(fetchinfo.links) do
					table.insert(ldflags, "-l" .. link)
				end
			end
		end

        if #cflags > 0 then
            io.replace(skia_gn, "cflags = []", 'cflags = ["' .. table.concat(cflags, '", "') .. '"]', {plain = true})
        end
        if #ldflags > 0 then
            io.replace(skia_gn, "ldflags = []", 'ldflags = ["' .. table.concat(ldflags, '", "') .. '"]', {plain = true})
        end

        -- installation
        import("package.tools.gn").build(package, args, {
            buildir = "out",
            envs = os.joinenvs(
                os.getenvs(),
                {
                    PATH = package:dep("python"):installdir("bin") .. ";" .. os.getenv("PATH"),
                }
            )
        })
        os.mv("include", package:installdir())
        for _, header in ipairs(os.dirs('modules/**.h')) do
            local relative_path = path.relative(header, 'modules')
            local dest_dir = path.directory(path.join(package:installdir(), 'modules', relative_path))

            os.mkdir(dest_dir)
            os.mv(header, dest_dir)
        end

        os.cd("out")
        os.rm("obj")
        os.rm("*.ninja")
        os.rm("*.ninja*")
        os.rm("*.gn")
        if package:is_plat("windows") then
            os.mv("*.lib", package:installdir("lib"))
            os.trymv("*.dll", package:installdir("bin"))
            os.mv("*.exe", package:installdir("bin"))
        else
            os.mv("*.a", package:installdir("lib"))
            os.trymv("*.so", package:installdir("lib"))
            os.trymv("*.dylib", package:installdir("lib"))
            os.trymv("*", package:installdir("bin"))
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            void test() {
                SkPaint paint;
                paint.setStyle(SkPaint::kFill_Style);
            }
        ]]}, {configs = {languages = "c++17"}, includes = "core/SkPaint.h"}))
    end)
package_end()
