require 'xcodeproj'
project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

llm_group = project.main_group.find_subpath(File.join('HomeScreen', 'LLM'), true)
if llm_group.nil?
  puts "Group not found or could not be created"
  exit
end

files_to_add = [
  'AIAssistantModels.swift',
  'AIAssistantService.swift',
  'AssistantDataProvider.swift',
  'AssistantViewController.swift',
  'VoiceRecognitionService.swift'
]

files_to_add.each do |filename|
  existing = llm_group.files.find { |f| f.path == filename || f.name == filename }
  if existing
    puts "#{filename} already in group"
    unless target.source_build_phase.files_references.include?(existing)
      target.source_build_phase.add_file_reference(existing)
      puts "Added #{filename} to target"
    end
  else
    file_ref = llm_group.new_file(filename)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added #{filename} to group and target"
  end
end

project.save
puts "Project saved."
