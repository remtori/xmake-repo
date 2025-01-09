import("core.base.option")
import("core.base.semver")
import("core.tool.toolchain")
import("lib.detect.find_tool")

local options =
{
    {'p', "plat",      "kv", os.host(), "Set platform"},
    {'a', "arch",      "kv", os.arch(), "Set architecture"},
    {'k', "kind",      "kv", nil,       "Set kind"},
    {'f', "configs",   "kv", nil,       "Set configs"}
}

function build_artifacts(name, version, opt)
    local argv = {"lua", "private.xrepo", "install", "-yvD", "--shallow", "--force", "--build", "-p", opt.plat, "-a", opt.arch, "-k", opt.kind}
    if opt.configs then
        table.insert(argv, "-f")
        table.insert(argv, opt.configs)
    end

    table.insert(argv, name .. " " .. version)
    os.execv("xmake", argv)
end

local msvc_version = ""
function _get_msvc_version(opt)
    if opt.plat == "windows" then
        local msvc = toolchain.load("msvc", {plat = opt.plat, arch = opt.arch})
        assert(msvc:check(), "msvc not found!")
        local vcvars = assert(msvc:config("vcvars"), "vcvars not found!")
        local vs_toolset = vcvars.VCToolsVersion
        if vs_toolset and semver.is_valid(vs_toolset) then
            msvc_version = "vc" .. vs_toolset
        end
    end
end

function export_artifacts(name, version, opt)
    local argv = {"lua", "private.xrepo", "export", "-yD", "--shallow", "-p", opt.plat, "-a", opt.arch, "-k", opt.kind}
    if opt.configs then
        table.insert(argv, "-f")
        table.insert(argv, opt.configs)
    end

    table.insert(argv, "-o")
    table.insert(argv, "dist")
    table.insert(argv, name .. " " .. version)

    os.mkdir("artifact")
    os.tryrm("dist")
    os.execv("xmake", argv)
    local build_hash
    for _, dir in ipairs(os.dirs(path.join("dist", "*", "*", "*", "*"))) do
        build_hash = path.filename(dir)
        break
    end

    assert(build_hash, "build_hash not found!")
    local old_dir = os.cd("dist")
    local artifact_file = table.concat({name, version, opt.plat, opt.arch, msvc_version, build_hash .. ".7z"}, "-")
    local z7 = assert(find_tool("7z"), "7z not found!")
    os.execv(z7.program, {"a", artifact_file, "*"})
    os.cd(old_dir)

    local final_artifact_file = "artifact/" .. artifact_file
    os.mv("dist/".. artifact_file, final_artifact_file)

    return final_artifact_file
end

function build(name, version, opt)
    build_artifacts(name, version, opt)
    return export_artifacts(name, version, opt)
end

function main(...)
    local argv = {"lua", "private.xrepo", "add-repo", "rtr", "https://github.com/remtori/xmake-repo.git", "main"}
    os.execv("xmake", argv)

    local cli_opt = option.parse(table.pack(...), options, "Build artifacts.", "", "Usage: xmake l scripts/build.lua [options]")
    _get_msvc_version(cli_opt)

    local build_infos = io.load(path.join(os.scriptdir(), "..", "build.lua"))
    for _, build_info in ipairs(build_infos) do
        local opt = table.join(cli_opt)
        if build_info.configs then
            if opt.configs then
                opt.configs = opt.configs .. "," .. build_info.configs
            else
                opt.configs = build_info.configs
            end
        end

        for _, version in ipairs(build_info.versions) do
            local artifact_file = build(build_info.name, version, opt)
            local tag = build_info.name .. "-" .. version
            print('built ' .. tag .. ' -> ' .. artifact_file)
            -- local found = try {function () os.execv("gh", {"release", "view", tag}); return true end}
            -- if found then
            --     try {function () os.execv("gh", {"release", "upload", "--clobber", tag, artifactfile}) end}
            -- else
            --     local created = try {function () os.execv("gh", {"release", "create", "--notes", tag .. " artifacts", tag, artifactfile}); return true end}
            --     if not created then
            --         try {function() os.execv("gh", {"release", "upload", "--clobber", tag, artifactfile}) end}
            --     end
            -- end
        end
    end
end
