require 'xcodeproj'
project_path = 'HomeScreen.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

home_screen_group = project.main_group.find_subpath(File.join('HomeScreen', 'Auth'), false)
if home_screen_group.nil?
  puts "Group not found"
else
  # check if file is already there
  existing = home_screen_group.files.find { |f| f.path == 'AppleAuthManager.swift' || f.name == 'AppleAuthManager.swift' }
  if existing
    puts "File already in group"
    unless target.source_build_phase.files_references.include?(existing)
      target.source_build_phase.add_file_reference(existing)
      puts "Added to target"
    end
  else
    file_ref = home_screen_group.new_file('AppleAuthManager.swift')
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added file to group and target"
  end
  project.save
end
