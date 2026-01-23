#!/usr/bin/env python3
import re
import random

def generate_uuid():
    """Generate Xcode-style 24-char hex ID"""
    hex_chars = '0123456789ABCDEF'
    return 'A1' + ''.join(random.choice(hex_chars) for _ in range(22))

# Read project file
with open('WeekAheadTodo.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Define new files
new_files = [
    {
        'name': 'CalendarService.swift',
        'path': 'Services/CalendarService.swift',
        'group': 'Services'
    },
    {
        'name': 'PatternDetectionService.swift',
        'path': 'Services/PatternDetectionService.swift',
        'group': 'Services'
    },
    {
        'name': 'CalendarEvent.swift',
        'path': 'Models/CalendarEvent.swift',
        'group': 'Models'
    },
    {
        'name': 'RecurrencePattern.swift',
        'path': 'Models/RecurrencePattern.swift',
        'group': 'Models'
    },
    {
        'name': 'CalendarViewModel.swift',
        'path': 'ViewModels/CalendarViewModel.swift',
        'group': 'ViewModels'
    },
    {
        'name': 'CalendarIntegrationView.swift',
        'path': 'Views/CalendarIntegrationView.swift',
        'group': 'Views'
    },
    {
        'name': 'PatternReviewView.swift',
        'path': 'Views/PatternReviewView.swift',
        'group': 'Views'
    },
    {
        'name': 'PatternDetailView.swift',
        'path': 'Views/PatternDetailView.swift',
        'group': 'Views'
    },
]

# Check if already added
if 'CalendarService.swift' in content:
    print("✓ Files already added to project!")
    exit(0)

# Generate IDs
file_data = []
for file_info in new_files:
    file_data.append({
        'info': file_info,
        'fileref_id': generate_uuid(),
        'buildfile_id': generate_uuid()
    })

# 1. Add to PBXBuildFile section
build_file_entries = []
for data in file_data:
    entry = f"\t\t{data['buildfile_id']} /* {data['info']['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {data['fileref_id']} /* {data['info']['name']} */; }};\n"
    build_file_entries.append(entry)

content = content.replace(
    '/* End PBXBuildFile section */',
    ''.join(build_file_entries) + '/* End PBXBuildFile section */'
)

# 2. Add to PBXFileReference section
file_ref_entries = []
for data in file_data:
    entry = f"\t\t{data['fileref_id']} /* {data['info']['name']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {data['info']['name']}; sourceTree = \"<group>\"; }};\n"
    file_ref_entries.append(entry)

content = content.replace(
    '/* End PBXFileReference section */',
    ''.join(file_ref_entries) + '/* End PBXFileReference section */'
)

# 3. Add to PBXGroup sections
# Add Services group
services_id = generate_uuid()
views_id = generate_uuid()

services_group = f"""\t\t{services_id} /* Services */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{[d['fileref_id'] for d in file_data if d['info']['group'] == 'Services'][0]} /* CalendarService.swift */,
\t\t\t\t{[d['fileref_id'] for d in file_data if d['info']['group'] == 'Services'][1]} /* PatternDetectionService.swift */,
\t\t\t);
\t\t\tpath = Services;
\t\t\tsourceTree = "<group>";
\t\t}};
"""

views_group = f"""\t\t{views_id} /* Views */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{[d['fileref_id'] for d in file_data if d['info']['group'] == 'Views'][0]} /* CalendarIntegrationView.swift */,
\t\t\t\t{[d['fileref_id'] for d in file_data if d['info']['group'] == 'Views'][1]} /* PatternReviewView.swift */,
\t\t\t\t{[d['fileref_id'] for d in file_data if d['info']['group'] == 'Views'][2]} /* PatternDetailView.swift */,
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t}};
"""

content = content.replace(
    '/* End PBXGroup section */',
    services_group + views_group + '/* End PBXGroup section */'
)

# Add new groups to main WeekAheadTodo group
models_match = re.search(r'(A1000005234567890000004 /\* Models \*/,)', content)
if models_match:
    insert_pos = models_match.end()
    new_groups_ref = f"\n\t\t\t\t{services_id} /* Services */,\n\t\t\t\t{views_id} /* Views */,"
    content = content[:insert_pos] + new_groups_ref + content[insert_pos:]

# Add new files to Models group
models_group_match = re.search(r'(A1000005234567890000004 /\* Models \*/ = \{[^}]*children = \([^)]*)(A1000002234567890000004 /\* TimeBlock\.swift \*/,)', content, re.DOTALL)
if models_group_match:
    calendar_event_ref = [d['fileref_id'] for d in file_data if d['info']['name'] == 'CalendarEvent.swift'][0]
    recurrence_pattern_ref = [d['fileref_id'] for d in file_data if d['info']['name'] == 'RecurrencePattern.swift'][0]

    new_models = f"\n\t\t\t\t{calendar_event_ref} /* CalendarEvent.swift */,\n\t\t\t\t{recurrence_pattern_ref} /* RecurrencePattern.swift */,"
    content = content[:models_group_match.end(2)] + new_models + content[models_group_match.end(2):]

# Add new file to ViewModels group
viewmodels_group_match = re.search(r'(A1000005234567890000005 /\* ViewModels \*/ = \{[^}]*children = \([^)]*)(A1000002234567890000005 /\* TaskViewModel\.swift \*/,)', content, re.DOTALL)
if viewmodels_group_match:
    calendar_vm_ref = [d['fileref_id'] for d in file_data if d['info']['name'] == 'CalendarViewModel.swift'][0]
    new_vm = f"\n\t\t\t\t{calendar_vm_ref} /* CalendarViewModel.swift */,"
    content = content[:viewmodels_group_match.end(2)] + new_vm + content[viewmodels_group_match.end(2):]

# 4. Add to PBXSourcesBuildPhase
sources_match = re.search(r'(A1000008234567890000001 /\* Sources \*/ = \{[^}]*files = \([^)]*)(A1000001234567890000005 /\* TaskViewModel\.swift in Sources \*/,)', content, re.DOTALL)
if sources_match:
    new_sources = []
    for data in file_data:
        new_sources.append(f"\n\t\t\t\t{data['buildfile_id']} /* {data['info']['name']} in Sources */,")
    content = content[:sources_match.end(2)] + ''.join(new_sources) + content[sources_match.end(2):]

# Backup and save
import shutil
shutil.copy('WeekAheadTodo.xcodeproj/project.pbxproj', 'WeekAheadTodo.xcodeproj/project.pbxproj.backup')

with open('WeekAheadTodo.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Successfully added files to Xcode project!")
print("📦 Backup created: project.pbxproj.backup")
print("\nAdded files:")
for file_info in new_files:
    print(f"  ✓ {file_info['path']}")
print("\n🚀 Now build the project: ⌘+B in Xcode")
