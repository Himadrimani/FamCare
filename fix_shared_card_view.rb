require 'xcodeproj'

project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'HomeScreen' }

# Find the group
group = project.main_group.find_subpath('HomeScreen/Messages/Views', true)

# Remove the wrong reference if it exists
wrong_ref = group.files.find { |f| f.path == 'HomeScreen/Messages/Views/SharedCardView.swift' || f.name == 'SharedCardView.swift' }
if wrong_ref
  wrong_ref.remove_from_project
end

# The actual path relative to project root is HomeScreen/Messages/Views/SharedCardView.swift
# But since group's path might be set, it's safer to use absolute path or let xcodeproj handle it
file_path = File.expand_path('HomeScreen/Messages/Views/SharedCardView.swift')
file_ref = group.new_file(file_path)

# Make sure it's added to the target
unless target.source_build_phase.files_references.include?(file_ref)
  target.add_file_references([file_ref])
end

project.save
puts "Successfully fixed #{file_path}"
