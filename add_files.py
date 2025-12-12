#!/usr/bin/env python3

import re
import uuid
import os

def generate_uuid():
    """Generate a 24-character hex string for Xcode IDs"""
    return uuid.uuid4().hex[:24].upper()

def add_files_to_pbxproj():
    pbxproj_path = 'WeekAheadTodo.xcodeproj/project.pbxproj'

    # Read the project file
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # New files to add
    files = [
        ('CalendarService.swift', 'WeekAheadTodo/Services/CalendarService.swift'),
        ('PatternDetectionService.swift', 'WeekAheadTodo/Services/PatternDetectionService.swift'),
        ('CalendarEvent.swift', 'WeekAheadTodo/Models/CalendarEvent.swift'),
        ('RecurrencePattern.swift', 'WeekAheadTodo/Models/RecurrencePattern.swift'),
        ('CalendarViewModel.swift', 'WeekAheadTodo/ViewModels/CalendarViewModel.swift'),
        ('CalendarIntegrationView.swift', 'WeekAheadTodo/Views/CalendarIntegrationView.swift'),
        ('PatternReviewView.swift', 'WeekAheadTodo/Views/PatternReviewView.swift'),
        ('PatternDetailView.swift', 'WeekAheadTodo/Views/PatternDetailView.swift'),
        ('Info.plist', 'WeekAheadTodo/Info.plist'),
    ]

    # Check if files already exist
    for filename, _ in files:
        if filename in content:
            print(f"⚠️  File already in project: {filename}")
            continue

    # Find the PBXBuildFile section
    build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/\n(.*?)/\* End PBXBuildFile section \*/', content, re.DOTALL)
    if not build_file_section:
        print("❌ Could not find PBXBuildFile section")
        return

    # Find the PBXFileReference section
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/\n(.*?)/\* End PBXFileReference section \*/', content, re.DOTALL)
    if not file_ref_section:
        print("❌ Could not find PBXFileReference section")
        return

    # Find the PBXSourcesBuildPhase section
    sources_section = re.search(r'/\* Begin PBXSourcesBuildPhase section \*/\n(.*?)/\* End PBXSourcesBuildPhase section \*/', content, re.DOTALL)
    if not sources_section:
        print("❌ Could not find PBXSourcesBuildPhase section")
        return

    # Find the PBXGroup section for WeekAheadTodo
    main_group_section = re.search(r'/\* WeekAheadTodo \*/ = \{[^}]*children = \([^)]*\);', content, re.DOTALL)
    if not main_group_section:
        print("❌ Could not find main group section")
        return

    new_build_files = []
    new_file_refs = []
    new_source_refs = []

    for filename, path in files:
        file_ref_id = generate_uuid()
        build_file_id = generate_uuid()

        # Skip Info.plist from sources
        if not filename.endswith('.plist'):
            # PBXBuildFile entry
            new_build_files.append(f"\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n")

            # Add to sources build phase
            new_source_refs.append(f"\t\t\t\t{build_file_id} /* {filename} in Sources */,\n")

        # PBXFileReference entry
        new_file_refs.append(f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n")

    # Insert new entries
    content = content.replace(
        '/* Begin PBXBuildFile section */',
        '/* Begin PBXBuildFile section */\n' + ''.join(new_build_files)
    )

    content = content.replace(
        '/* Begin PBXFileReference section */',
        '/* Begin PBXFileReference section */\n' + ''.join(new_file_refs)
    )

    # Add to sources build phase
    sources_match = re.search(r'(isa = PBXSourcesBuildPhase;.*?files = \()(.*?)(\);)', content, re.DOTALL)
    if sources_match:
        existing_files = sources_match.group(2)
        new_sources = sources_match.group(1) + existing_files + ''.join(new_source_refs) + sources_match.group(3)
        content = content[:sources_match.start()] + new_sources + content[sources_match.end():]

    # Backup original
    os.rename(pbxproj_path, pbxproj_path + '.backup')

    # Write updated content
    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print("✅ Files added to Xcode project!")
    print(f"📦 Backup saved: {pbxproj_path}.backup")
    print("\nAdded files:")
    for filename, path in files:
        print(f"  ✓ {path}")
    print("\nNow open the project in Xcode and build (⌘+B)")

if __name__ == '__main__':
    add_files_to_pbxproj()
