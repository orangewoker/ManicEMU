#!/usr/bin/env python3
"""Add the JavaPocket iOS target to the existing ManicEmu Xcode project.

Development-only helper. Requires `pip install pbxproj==4.3.2`.
It is intentionally idempotent and does not modify the legacy targets.
"""

import os
from pathlib import Path

from pbxproj import PBXGenericObject, XcodeProject
from pbxproj.PBXKey import PBXKey
from pbxproj.pbxextensions.ProjectFiles import FileOptions
from pbxproj.pbxsections import (
    PBXBuildFile,
    PBXFileReference,
    PBXFrameworksBuildPhase,
    PBXNativeTarget,
    PBXResourcesBuildPhase,
    PBXSourcesBuildPhase,
    XCBuildConfiguration,
    XCConfigurationList,
)


ROOT = Path(__file__).resolve().parents[1]
PROJECT_PATH = ROOT / "ManicEmu" / "ManicEmu.xcodeproj" / "project.pbxproj"
TARGET_NAME = "JavaPocket"


def add_object(project: XcodeProject, obj):
    project.objects[obj.get_id()] = obj
    return obj


def make_object(cls, values):
    values = {"_id": cls._generate_id(), "isa": cls.__name__, **values}
    return cls().parse(values)


def main() -> None:
    project = XcodeProject.load(str(PROJECT_PATH))
    existing = project.get_target_by_name(TARGET_NAME)
    if existing:
        print(f"{TARGET_NAME} target already exists: {existing.get_id()}")
        return

    sources = add_object(project, PBXSourcesBuildPhase.create())
    resources = add_object(project, PBXResourcesBuildPhase.create())
    frameworks = add_object(project, PBXFrameworksBuildPhase.create())

    common_settings = {
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CLANG_ENABLE_MODULES": "YES",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "13",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "../JavaPocket/Resources/Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": "1.0.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.javapocket.emulator",
        "PRODUCT_MODULE_NAME": "JavaPocket",
        "PRODUCT_NAME": "JavaPocket",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    debug = add_object(
        project,
        make_object(
            XCBuildConfiguration,
            {
                "name": "Debug",
                "buildSettings": PBXGenericObject().parse(
                    {**common_settings, "SWIFT_OPTIMIZATION_LEVEL": "-Onone"}
                ),
            },
        ),
    )
    release = add_object(
        project,
        make_object(
            XCBuildConfiguration,
            {
                "name": "Release",
                "buildSettings": PBXGenericObject().parse(
                    {**common_settings, "SWIFT_COMPILATION_MODE": "wholemodule"}
                ),
            },
        ),
    )
    configuration_list = add_object(
        project,
        make_object(
            XCConfigurationList,
            {
                "buildConfigurations": [debug.get_id(), release.get_id()],
                "defaultConfigurationIsVisible": 0,
                "defaultConfigurationName": "Release",
            },
        ),
    )

    product = PBXFileReference.create("JavaPocket.app", tree="BUILT_PRODUCTS_DIR")
    product.set_explicit_file_type("wrapper.application")
    add_object(project, product)

    package_dependencies = []
    for name in ("ZIPFoundation", "GCDWebUploader"):
        dependency = project.get_package_dependency_by_name(name)
        if dependency is None:
            raise RuntimeError(f"Missing existing Swift package product: {name}")
        package_dependencies.append(dependency.get_id())
        build_file = add_object(project, PBXBuildFile.create(dependency, is_product=True))
        frameworks.add_build_file(build_file)

    target = add_object(
        project,
        make_object(
            PBXNativeTarget,
            {
                "buildConfigurationList": configuration_list.get_id(),
                "buildPhases": [sources.get_id(), frameworks.get_id(), resources.get_id()],
                "buildRules": [],
                "dependencies": [],
                "name": TARGET_NAME,
                "packageProductDependencies": package_dependencies,
                "productName": TARGET_NAME,
                "productReference": product.get_id(),
                "productType": "com.apple.product-type.application",
            },
        ),
    )

    root_project = project.objects[project.rootObject]
    # JavaPocket is the only active product. Legacy targets and their objects stay
    # in project history, but are unreachable from the project build graph.
    root_project.targets = [target.get_id()]
    root_project.packageReferences = [
        project.get_package_dependency_by_name("ZIPFoundation").package,
        project.get_package_dependency_by_name("GCDWebUploader").package,
    ]
    products_group = project.objects[root_project.productRefGroup]
    products_group.add_child(product)

    main_group = project.objects[root_project.mainGroup]
    java_group = project.add_group("JavaPocket", parent=main_group)
    file_options = FileOptions(add_groups_relative=False)
    source_root = ROOT / "JavaPocket" / "Sources"
    for source in sorted(source_root.rglob("*.swift")):
        relative = Path(os.path.relpath(source, ROOT / "ManicEmu")).as_posix()
        project.add_file(
            relative,
            parent=java_group,
            tree="SOURCE_ROOT",
            target_name=TARGET_NAME,
            file_options=file_options,
        )

    info_relative = Path(
        os.path.relpath(ROOT / "JavaPocket" / "Resources" / "Info.plist", ROOT / "ManicEmu")
    ).as_posix()
    project.add_file(
        info_relative,
        parent=java_group,
        tree="SOURCE_ROOT",
        target_name=[],
        file_options=FileOptions(create_build_files=False, add_groups_relative=False),
    )
    assets_relative = Path(
        os.path.relpath(ROOT / "JavaPocket" / "Resources" / "Assets.xcassets", ROOT / "ManicEmu")
    ).as_posix()
    project.add_file(
        assets_relative,
        parent=java_group,
        tree="SOURCE_ROOT",
        target_name=TARGET_NAME,
        file_options=file_options,
    )

    skin_relative = Path(
        os.path.relpath(ROOT / "JavaPocket" / "Resources" / "ManicJ2MESkin", ROOT / "ManicEmu")
    ).as_posix()
    project.add_file(
        skin_relative,
        parent=java_group,
        tree="SOURCE_ROOT",
        target_name=TARGET_NAME,
        file_options=file_options,
    )

    runtime = PBXFileReference.create("../System.core/freej2me", tree="SOURCE_ROOT")
    runtime["name"] = "freej2me"
    runtime.set_last_known_file_type("folder")
    add_object(project, runtime)
    java_group.add_child(runtime)
    runtime_build_file = add_object(project, PBXBuildFile.create(runtime))
    resources.add_build_file(runtime_build_file)

    j2mejs_runtime = PBXFileReference.create("../System.core/j2mejs", tree="SOURCE_ROOT")
    j2mejs_runtime["name"] = "j2mejs"
    j2mejs_runtime.set_last_known_file_type("folder")
    add_object(project, j2mejs_runtime)
    java_group.add_child(j2mejs_runtime)
    j2mejs_build_file = add_object(project, PBXBuildFile.create(j2mejs_runtime))
    resources.add_build_file(j2mejs_build_file)

    # pbxproj 4.3.2 leaves references created in-memory as plain strings in
    # a few paths. Wrap them so comments can be resolved during serialization.
    for build_file in project.objects.get_objects_in_section("PBXBuildFile"):
        for key in ("fileRef", "productRef"):
            value = getattr(build_file, key, None)
            if type(value) is str:
                setattr(build_file, key, PBXKey(value, build_file))

    temporary_project = PROJECT_PATH.with_suffix(".pbxproj.tmp")
    project.save(str(temporary_project))
    XcodeProject.load(str(temporary_project))
    temporary_project.replace(PROJECT_PATH)
    write_scheme(target.get_id())
    print(f"Added {TARGET_NAME} target: {target.get_id()}")


def write_scheme(target_id: str) -> None:
    scheme_directory = ROOT / "ManicEmu" / "ManicEmu.xcodeproj" / "xcshareddata" / "xcschemes"
    scheme_directory.mkdir(parents=True, exist_ok=True)
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
        <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="JavaPocket.app" BlueprintName="JavaPocket" ReferencedContainer="container:ManicEmu.xcodeproj"/>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="JavaPocket.app" BlueprintName="JavaPocket" ReferencedContainer="container:ManicEmu.xcodeproj"/>
    </BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="JavaPocket.app" BlueprintName="JavaPocket" ReferencedContainer="container:ManicEmu.xcodeproj"/>
    </BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (scheme_directory / "JavaPocket.xcscheme").write_text(scheme, encoding="utf-8")


if __name__ == "__main__":
    main()
