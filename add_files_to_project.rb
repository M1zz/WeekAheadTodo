#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'WeekAheadTodo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the main group
main_group = project.main_group['WeekAheadTodo']

# Create groups if they don't exist
services_group = main_group['Services'] || main_group.new_group('Services')
views_group = main_group['Views'] || main_group.new_group('Views')
models_group = main_group['Models']
viewmodels_group = main_group['ViewModels']

# Files to add
files_to_add = [
  { path: 'WeekAheadTodo/Services/CalendarService.swift', group: services_group },
  { path: 'WeekAheadTodo/Services/PatternDetectionService.swift', group: services_group },
  { path: 'WeekAheadTodo/Models/CalendarEvent.swift', group: models_group },
  { path: 'WeekAheadTodo/Models/RecurrencePattern.swift', group: models_group },
  { path: 'WeekAheadTodo/ViewModels/CalendarViewModel.swift', group: viewmodels_group },
  { path: 'WeekAheadTodo/Views/CalendarIntegrationView.swift', group: views_group },
  { path: 'WeekAheadTodo/Views/PatternReviewView.swift', group: views_group },
  { path: 'WeekAheadTodo/Views/PatternDetailView.swift', group: views_group },
  { path: 'WeekAheadTodo/Info.plist', group: main_group }
]

files_to_add.each do |file_info|
  file_path = file_info[:path]
  group = file_info[:group]

  # Check if file already exists in project
  existing = group.files.find { |f| f.path == File.basename(file_path) }

  unless existing
    # Add file reference
    file_ref = group.new_reference(file_path)

    # Add to build phase if it's a Swift file
    if file_path.end_with?('.swift')
      target.source_build_phase.add_file_reference(file_ref)
    elsif file_path.end_with?('.plist')
      target.resources_build_phase.add_file_reference(file_ref)
    end

    puts "✓ Added: #{file_path}"
  else
    puts "○ Already exists: #{file_path}"
  end
end

# Save the project
project.save

puts "\n✅ Project updated successfully!"
puts "Now build the project in Xcode (⌘+B)"
