require 'xcodeproj'
project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

llm_group = project.main_group.find_subpath(File.join('HomeScreen', 'LLM'), true)

# Remove AIAssistantService.swift
old_file = llm_group.files.find { |f| f.path == 'AIAssistantService.swift' || f.name == 'AIAssistantService.swift' }
if old_file
  old_file.build_files.each { |bf| bf.remove_from_project }
  old_file.remove_from_project
  puts "Removed AIAssistantService.swift"
end

# Add AppleAssistantService.swift
new_file_name = 'AppleAssistantService.swift'
existing = llm_group.files.find { |f| f.path == new_file_name || f.name == new_file_name }
if existing
  unless target.source_build_phase.files_references.include?(existing)
    target.source_build_phase.add_file_reference(existing)
  end
else
  file_ref = llm_group.new_file(new_file_name)
  target.source_build_phase.add_file_reference(file_ref)
end

project.save
puts "Project updated"
